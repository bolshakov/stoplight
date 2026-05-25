# frozen_string_literal: true

require "cgi/escape"
require "cgi/util" if RUBY_VERSION < "3.5"
require "digest"

begin
  require "sinatra/base"
  require "sinatra/json"
rescue LoadError
  raise <<~WARN
    "sinatra" and "sinatra-contrib" gems are unavailable and necessary for running Stoplight Admin panel
    Please add them to your Gemfile and run `bundle install`:
      gem "sinatra", required: false
      gem "sinatra-contrib", require: false
  WARN
end

module Stoplight
  class Admin < Sinatra::Base
    COLORS = [
      GREEN = Stoplight::Color::GREEN,
      YELLOW = Stoplight::Color::YELLOW,
      RED = Stoplight::Color::RED
    ].freeze
    private_constant :COLORS

    ASSETS_PATH = File.join(__dir__, "admin", "assets")
    ASSET_DIGESTS = Dir.children(ASSETS_PATH).each_with_object({}) do |name, h|
      h[name] = Digest::SHA256.file(File.join(ASSETS_PATH, name)).hexdigest[0, 8]
    end.freeze

    ONE_YEAR_IN_SECONDS = 60 * 60 * 24 * 365
    private_constant :ONE_YEAR_IN_SECONDS

    helpers Helpers

    set :protection, except: %i[json_csrf]
    set :data_store, proc { Stoplight.__stoplight__default_configuration.data_store }
    set :views, File.join(__dir__, "admin", "views")
    set :nonce, proc { |request| }
    set :public_folder, ASSETS_PATH
    set :static_cache_control, [:public, max_age: ONE_YEAR_IN_SECONDS, immutable: true]

    get "/" do
      lights, stats = dependencies.stats_action.call

      erb :index, locals: stats.merge(lights: lights, nonce: settings.nonce(request))
    end

    get "/stats" do
      lights, stats = dependencies.stats_action.call

      json({stats: stats, lights: lights.map(&:as_json)})
    end

    post "/unlock" do
      dependencies.unlock_action.call(params)

      redirect to("/")
    end

    post "/green" do
      dependencies.green_action.call(params)

      redirect to("/")
    end

    post "/red" do
      dependencies.red_action.call(params)

      redirect to("/")
    end

    post "/green_all" do
      dependencies.green_all_action.call

      redirect to("/")
    end

    post "/remove" do
      dependencies.remove_action.call(params)

      redirect to("/")
    end
  end
end
