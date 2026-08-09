# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::Redis::Storage::Scripting, :redis do
  subject(:script_manager) { script_manager_factory }

  let(:script_file) { Tempfile.create(["script", ".lua"]) }
  let(:script_file_path) { Pathname.new(script_file.path) }
  let(:scripts_root) { script_file_path.dirname.to_s }
  let(:script_name) { script_file_path.basename.to_s.sub(".lua", "").to_sym }
  let(:script) { <<~LUA }
    local value = ARGV[1]
    local key = KEYS[1]

    return redis.call("SET", key, value)
  LUA

  around do |example|
    script_file.puts(script)
    script_file.rewind
    example.run
  end

  let(:value) { SecureRandom.uuid }
  let(:key) { SecureRandom.uuid }

  def script_manager_factory = described_class.new(redis:, scripts_root:)

  it "can call existing script" do
    result = script_manager.call(script_name, args: [value], keys: [key])
    expect(result).to eq("OK")
    expect(redis.get(key)).to eq(value)
  end

  it "fails when calling unknown script" do
    expect do
      script_manager.call("bang", args: [value], keys: [key])
    end.to raise_error(Errno::ENOENT)
  end

  it "re-loads the script if it gets evicted" do
    script_manager.call(script_name, args: [value], keys: [key])

    redis.script(:flush)

    updated_value = SecureRandom.uuid
    script_manager.call(script_name, args: [updated_value], keys: [key])
    expect(redis.get(key)).to eq(updated_value)
  end

  context "when the script includes another script" do
    let(:script) { <<~LUA }
      -- @include multiply
      local factor = tonumber(ARGV[1])
      local key = KEYS[1]

      return redis.call("SET", key, multiply(factor, 2))
    LUA

    before do
      File.write(File.join(scripts_root, "multiply.lua"), <<~LUA)
        local function multiply(a, b)
          return a * b
        end
      LUA
    end

    after do
      File.delete(File.join(scripts_root, "multiply.lua"))
    end

    it "splices the included script's source into the calling script" do
      script_manager.call(script_name, args: [21], keys: [key])

      expect(redis.get(key)).to eq("42")
    end
  end

  context "when an included script itself includes another script" do
    let(:script) { <<~LUA }
      -- @include multiply
      local factor = tonumber(ARGV[1])
      local key = KEYS[1]

      return redis.call("SET", key, multiply_by_four(factor))
    LUA

    before do
      File.write(File.join(scripts_root, "multiply.lua"), <<~LUA)
        -- @include multiply/double
        local function multiply_by_four(a)
          return double(double(a))
        end
      LUA
      File.write(File.join(scripts_root, "multiply", "double.lua"), <<~LUA)
        local function double(a)
          return a * 2
        end
      LUA
    end

    around do |example|
      Dir.mkdir(File.join(scripts_root, "multiply"))
      example.run
    ensure
      FileUtils.rm_rf(File.join(scripts_root, "multiply"))
    end

    after do
      File.delete(File.join(scripts_root, "multiply.lua"))
    end

    it "resolves transitively included scripts" do
      script_manager.call(script_name, args: [21], keys: [key])

      expect(redis.get(key)).to eq("84")
    end
  end

  context "when the script includes more than one other script" do
    let(:script) { <<~LUA }
      -- @include double
      -- @include triple
      local factor = tonumber(ARGV[1])
      local key = KEYS[1]

      return redis.call("SET", key, triple(double(factor)))
    LUA

    before do
      File.write(File.join(scripts_root, "double.lua"), <<~LUA)
        local function double(a)
          return a * 2
        end
      LUA
      File.write(File.join(scripts_root, "triple.lua"), <<~LUA)
        local function triple(a)
          return a * 3
        end
      LUA
    end

    after do
      File.delete(File.join(scripts_root, "double.lua"))
      File.delete(File.join(scripts_root, "triple.lua"))
    end

    it "splices in every included script" do
      script_manager.call(script_name, args: [7], keys: [key])

      expect(redis.get(key)).to eq("42")
    end
  end

  context "when the script includes a script that does not exist" do
    let(:script) { <<~LUA }
      -- @include does-not-exist
      return "unreachable"
    LUA

    it "raises rather than silently skipping the include" do
      expect do
        script_manager.call(script_name, args: [value], keys: [key])
      end.to raise_error(Errno::ENOENT)
    end
  end

  context "when the include target attempts to traverse outside scripts_root" do
    let(:script) { <<~LUA }
      -- @include ../../../../../../etc/passwd
      return "safe"
    LUA

    it "treats the directive as inert instead of reading outside scripts_root" do
      result = script_manager.call(script_name, args: [value], keys: [key])

      expect(result).to eq("safe")
    end
  end

  context "when the script itself raises an error unrelated to a missing script" do
    let(:script) { <<~LUA }
      return redis.call("THIS-IS-NOT-A-REAL-COMMAND")
    LUA

    it "propagates the error instead of retrying" do
      expect do
        script_manager.call(script_name, args: [value], keys: [key])
      end.to raise_error(::Redis::CommandError) { |error| expect(error.message).not_to include("NOSCRIPT") }
    end
  end

  context "when the script is not loaded" do
    # Initial call plus one retry
    let(:total_attempts) { 2 }

    it "does not propagate error if retry succeeds" do
      responses = [
        -> { raise ::Redis::CommandError.new("NOSCRIPT") },    # Initial call fails
        -> { "success" }                                       # retry succeeds
      ]

      allow(redis).to receive(:evalsha) { responses.shift.call }

      script_manager.call(script_name, args: [value], keys: [key])
      expect(redis).to have_received(:evalsha).exactly(total_attempts).times
    end

    it "propagates error if retries are exhausted" do
      responses = [
        -> { raise ::Redis::CommandError.new("NOSCRIPT") },    # Initial call fails
        -> { raise ::Redis::CommandError.new("NOSCRIPT") }     # retry also fails => raise
      ]

      allow(redis).to receive(:evalsha) { responses.shift.call }

      expect do
        script_manager.call(script_name, args: [value], keys: [key])
      end.to raise_error(::Redis::CommandError)
      expect(redis).to have_received(:evalsha).exactly(total_attempts).times
    end
  end

  context "when two scripting instances call the same script" do
    let(:script_sha) { Digest::SHA1.hexdigest(script) }

    before do
      redis.script(:flush, :sync)
    end

    it "loads script only once" do
      expect(redis).to receive(:script).with(:load, script).and_call_original.once

      script_manager1 = script_manager_factory
      script_manager1.call(script_name, args: [value], keys: [key])

      expect(redis).not_to receive(:script)
      script_manager2 = script_manager_factory

      script_manager2.call(script_name, args: [value], keys: [key])
    end
  end
end
