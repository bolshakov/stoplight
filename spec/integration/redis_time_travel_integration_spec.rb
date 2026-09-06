# frozen_string_literal: true

RSpec.describe "Redis time travel integration", :redis do
  let(:script_manager) { Stoplight::Infrastructure::Redis::Storage::Scripting.new(redis:) }
  let(:test_script_name) { :test_now_integration }
  let(:test_script_path) { Pathname.new(Dir.tmpdir).join(SecureRandom.uuid) }

  before do
    Dir.mkdir(test_script_path.to_s)
    support_lua_path = Pathname.new(File.expand_path("../support/lua", __dir__)).to_s
    script_manager_with_path = Stoplight::Infrastructure::Redis::Storage::Scripting.new(
      redis:,
      scripts_path: [test_script_path.to_s, support_lua_path]
    )
    @script_manager = script_manager_with_path

    script_content = <<~LUA
      -- @include now
      return now()
    LUA
    File.write(test_script_path.join("test_now_integration.lua"), script_content)
  end

  after do
    FileUtils.rm_rf(test_script_path.to_s)
  end

  describe "now() with TimeTravel.freeze" do
    it "returns frozen time from within Lua script" do
      frozen_time = Time.new(2025, 6, 15, 14, 30, 45)

      Stoplight::TimeTravel.freeze(frozen_time) do
        result = @script_manager.call(test_script_name, keys: [], args: [])
        expected_ms = (frozen_time.to_f * 1000).to_i

        expect(result).to eq(expected_ms)
      end
    end

    it "preserves nested freeze contexts" do
      start_time = Time.new(2025, 1, 1, 12, 0, 0)
      inner_time = Time.new(2025, 6, 15, 14, 30, 45)

      Stoplight::TimeTravel.freeze(start_time) do
        outer_result = @script_manager.call(test_script_name, keys: [], args: [])

        Stoplight::TimeTravel.freeze(inner_time) do
          inner_result = @script_manager.call(test_script_name, keys: [], args: [])
          expect(inner_result).to eq((inner_time.to_f * 1000).to_i)
        end

        # After inner freeze exits, outer freeze is restored
        restored_result = @script_manager.call(test_script_name, keys: [], args: [])
        expect(restored_result).to eq(outer_result)
      end
    end
  end

  describe "now() returns actual time when not mocked" do
    it "returns current Redis server time" do
      result = @script_manager.call(test_script_name, keys: [], args: [])

      now_ms = (Time.now.to_f * 1000).to_i
      # Allow 1 second tolerance for test execution time
      expect(result).to be_within(1000).of(now_ms)
    end
  end
end
