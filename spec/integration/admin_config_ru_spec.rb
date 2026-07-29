# frozen_string_literal: true

require "rack/test"
require "rack/builder"

RSpec.describe "config.ru", :redis do
  include Rack::Test::Methods

  let(:app) { Rack::Builder.parse_file(File.expand_path("../../config.ru", __dir__)) }

  around do |example|
    original_redis_url = ENV["REDIS_URL"]
    ENV["REDIS_URL"] = ENV.fetch("STOPLIGHT_REDIS_URL", "redis://127.0.0.1:6379/0")
    example.run
  ensure
    ENV["REDIS_URL"] = original_redis_url
  end

  before { Stoplight.__stoplight__reset! }

  it "surfaces a light a separate process already wrote to the same Redis" do
    Stoplight.configure(trust_me_im_an_engineer: true) { |config| config.data_store = Stoplight::DataStore::Redis.new(redis) }
    Stoplight.register("foo")
    Stoplight.light("foo").run { "ok" }
    Stoplight.__stoplight__reset!

    get "/"

    expect(last_response.body).not_to include("No lights found")
  end
end
