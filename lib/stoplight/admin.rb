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
  #   Core = Stoplight.register_system("Core", data_store:)
  #   Analytics = Stoplight.register_system("Analytics", data_store:)
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
      unless system.persistent?
        raise TypeError, "Stoplight Admin requires a persistent data store, but the current data store is not. " \
          "Please configure a different data store in your Stoplight configuration."
      end

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
      system = settings.systems.first

      redirect to("/systems/#{system.config.id}/lights")
    end

    get "/systems/:system_id/lights" do
      system_id = T.must(params[:system_id])
      system = find_system(system_id)

      lights, stats = dependencies(system).stats_action.call

      erb :index, locals: stats.merge(lights: lights, nonce: settings.nonce(request))
    end

    # Keep this endpoint for backward compatibility. Any monitoring system polling this
    # endpoint keep receiving the first system's (likely default one) lighs
    get "/stats" do
      lights, stats = dependencies(settings.systems.first).stats_action.call

      json({stats: stats, lights: lights.map(&:as_json)})
    end

    get "/systems/:system_id/lights.json" do
      system_id = T.must(params[:system_id])
      system = find_system(system_id)
      lights, stats = dependencies(system).stats_action.call

      json({stats: stats, lights: lights.map(&:as_json)})
    end

    patch "/:light_id/unlock" do
      light_id = T.must(params[:light_id])
      dependencies(settings.systems.first).unlock_action.call(light_id:)

      redirect to("/")
    end

    patch "/:light_id/lock" do
      light_id = T.must(params[:light_id])
      color = T.must(params[:color])
      dependencies(settings.systems.first).lock_action.call(light_id:, color:)

      redirect to("/")
    end

    patch "/lock" do
      color = T.must(params[:color])
      dependencies(settings.systems.first).lock_all_action.call(color:)

      redirect to("/")
    end

    delete "/:light_id" do
      light_id = T.must(params[:light_id])
      dependencies(settings.systems.first).remove_action.call(light_id:)

      redirect to("/")
    end
  end
end
