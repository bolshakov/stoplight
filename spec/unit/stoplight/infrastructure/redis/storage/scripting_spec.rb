# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::Redis::Storage::Scripting, :redis do
  subject(:script_manager) { described_class.new(redis:, scripts_root:) }

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
end
