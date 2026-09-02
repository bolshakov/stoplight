# frozen_string_literal: true

# For :redis specs with TimeTravel, Lua scripts need test stub version of now() that reads
# frozen time from Redis stack, not production version that calls redis.call("TIME").
# This hook makes that transparent: all :redis specs get the stubs path prepended.

STUBS_PATH = File.expand_path("../stubs", __FILE__)
PROD_PATHS = Stoplight::Infrastructure::Redis::Storage::Scripting.default_scripts_path

RSpec.configure do |config|
  config.before(:each, :redis) do
    allow(Stoplight::Infrastructure::Redis::Storage::Scripting)
      .to receive(:default_scripts_path)
      .and_return([STUBS_PATH, *PROD_PATHS])
  end
end
