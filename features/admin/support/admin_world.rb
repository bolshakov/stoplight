# frozen_string_literal: true

require "rack/test"
require "redis"
require "database_cleaner/redis"

module AdminWorld
  include Rack::Test::Methods

  def app = Stoplight::Admin::Panel

  def default_host = "localhost"

  def reset!
    Stoplight.__stoplight__reset!
    Stoplight::Admin.__stoplight__reset_systems!
    DatabaseCleaner[:redis].db = redis
    DatabaseCleaner.clean_with(:deletion)
  end

  def redis
    @redis ||= Redis.new(url: ENV.fetch("STOPLIGHT_REDIS_URL", "redis://127.0.0.1:6379/0"))
  end

  def configure_system(name)
    system = Stoplight.register_system(name, data_store: Stoplight::DataStore::Redis.new(redis))
    Stoplight::Admin.add_system(system)
    configured_systems[name] = system
  end

  def system_named(name)
    configured_systems.fetch(name)
  end

  def configured_systems
    @configured_systems ||= {}
  end

  def system_for(light_reference)
    return Stoplight.__stoplight__default_system unless light_reference.system_name

    system_named(light_reference.system_name)
  end

  def find_light(light_reference)
    system_for(light_reference).light(light_reference.name)
  end

  def light_path(light_reference, suffix = "")
    system_id = system_for(light_reference).config.id
    light_id = Stoplight::Domain::Id.for(light_reference.name)

    "/systems/#{system_id}/lights/#{light_id}#{suffix}"
  end

  def lights_path(system)
    "/systems/#{system.config.id}/lights"
  end

  def fail_request(light)
    light.run { raise "Service unavailable" }
  rescue RuntimeError, Stoplight::Error::RedLight
    nil
  end
end
