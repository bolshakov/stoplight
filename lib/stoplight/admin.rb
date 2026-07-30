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
  # A Sinatra dashboard listing every light, its color, and its recent failures, with
  # controls to lock a light green or red, unlock it, or remove it.
  #
  # Setting +read_only+ deploys it as an observation-only dashboard: every light stays
  # visible, and every control that would change one is refused with 403 rather than merely
  # hidden, so calling the endpoints directly does not get around it. The standalone Docker
  # image reads the same option from +STOPLIGHT_ADMIN_READ_ONLY+, for the exact string +true+.
  #
  # This is not access control - it has no notion of users, and anyone who reaches the panel
  # still reads every light name and failure message. Keep it behind authentication either way.
  #
  # @example Observing without being able to change anything
  #   Stoplightt::Admin.conrfigure do |config|
  #     config.read_only = true
  #   end
  #
  #   mount Stoplight::Admin => "/stoplights"
  #
  # @example configue multiple systems
  #   Core = Stoplight.__stoplight__system("Core", data_store:)
  #   Analytics = Stoplight.__stoplight__system("Analytics", data_store:)
  #
  #   Stoplight::Admin.configure do |config|
  #     config.add_system Core
  #     config.add_system Analytics
  #   end
  #
  class Admin < Sinatra::Base
    COLORS = [
      Color::GREEN,
      Color::YELLOW,
      Color::RED
    ].freeze
    private_constant :COLORS

    ASSETS_PATH = File.join(T.must(__dir__), "admin", "assets")
    ASSET_DIGESTS = Dir.children(ASSETS_PATH).to_h do |name|
      [name, T.must(Digest::SHA256.file(File.join(ASSETS_PATH, name)).hexdigest[0, 8])]
    end.freeze

    ONE_YEAR_IN_SECONDS = 60 * 60 * 24 * 365
    private_constant :ONE_YEAR_IN_SECONDS

    helpers Helpers
    @systems = []

    def self.add_system(system)
      @systems << system
    end

    set :systems do
      if @systems.empty?
        [Stoplight.__stoplight__default_system]
      else
        @systems
      end
    end

    set :protection, except: %i[json_csrf]
    set :read_only, false
    set :data_store, proc { Stoplight.__stoplight__default_configuration.data_store }
    set :views, File.join(T.must(__dir__), "admin", "views")
    set :nonce, proc { |request| }
    set :public_folder, ASSETS_PATH
    set :static_cache_control, [:public, max_age: ONE_YEAR_IN_SECONDS, immutable: true]

    # Gates on the request method rather than on a list of paths, so a write route added
    # later is refused without anyone having to remember this filter exists.
    before do
      if settings.read_only? && !request.get? && !request.head?
        halt 403, "Stoplight Admin is running in read-only mode."
      end
    end

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
