# frozen_string_literal: true

require "rack/test"
require "rack/builder"

RSpec.describe "config.ru", :redis do
  include Rack::Test::Methods

  let(:app) { Rack::Builder.parse_file(File.expand_path("../../config.ru", __dir__)) }
  let(:light_id) { SecureRandom.uuid }

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
    system_id = Stoplight.__stoplight__default_system.config.id

    patch "/systems/#{system_id}/lights/#{light_id}/lock", color: "green"

    expect(last_response.status).to eq(403)
  end

  it "leaves the panel writable when STOPLIGHT_ADMIN_READ_ONLY holds any other value" do
    ENV["STOPLIGHT_ADMIN_READ_ONLY"] = "1"
    app # force config.ru's Stoplight.configure to run before registering the light
    Stoplight.register("foo")
    system_id = Stoplight.__stoplight__default_system.config.id

    patch "/systems/#{system_id}/lights/#{Stoplight::Domain::Id.for("foo")}/lock", color: "green"

    expect(last_response.status).to eq(302)
    expect(Stoplight.light("foo").state).to eq("locked_green")
  end

  it "surfaces a light a separate process already wrote to the same Redis" do
    Stoplight.configure(trust_me_im_an_engineer: true) { |config| config.data_store = Stoplight::DataStore::Redis.new(redis) }
    Stoplight.register("foo")
    Stoplight.light("foo").run { "ok" }
    Stoplight.__stoplight__reset!
    system_id = Stoplight.__stoplight__default_system.config.id

    get "/systems/#{system_id}/lights"

    expect(last_response.body).not_to include("No lights found")
  end
end
