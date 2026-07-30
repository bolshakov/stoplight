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

  around do |example|
    original_read_only = Stoplight::Admin.settings.read_only
    original_environment = Stoplight::Admin.settings.environment
    original_env = ENV["STOPLIGHT_ADMIN_READ_ONLY"]
    example.run
  ensure
    Stoplight::Admin.set :read_only, original_read_only
    Stoplight::Admin.set :environment, original_environment
    ENV["STOPLIGHT_ADMIN_READ_ONLY"] = original_env
  end

  before { Stoplight.__stoplight__reset! }

  it "runs the panel read-only when STOPLIGHT_ADMIN_READ_ONLY is true" do
    ENV["STOPLIGHT_ADMIN_READ_ONLY"] = "true"

    post "/green", names: "foo"

    expect(last_response.status).to eq(403)
  end

  it "leaves the panel writable when STOPLIGHT_ADMIN_READ_ONLY holds any other value" do
    ENV["STOPLIGHT_ADMIN_READ_ONLY"] = "1"

    post "/green", names: "foo"

    expect(last_response.status).to eq(302)
  end

  it "surfaces a light a separate process already wrote to the same Redis" do
    Stoplight.configure(trust_me_im_an_engineer: true) { |config| config.data_store = Stoplight::DataStore::Redis.new(redis) }
    Stoplight.register("foo")
    Stoplight.light("foo").run { "ok" }
    Stoplight.__stoplight__reset!

    get "/"

    expect(last_response.body).not_to include("No lights found")
  end
end
