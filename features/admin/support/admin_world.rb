# frozen_string_literal: true

require "rack/test"
require "redis"
require "database_cleaner/redis"
require "nokogiri"

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

  def document
    Nokogiri::HTML5(last_response.body)
  end

  def lights_path(system)
    "/systems/#{system.config.id}/lights"
  end

  def listed_light_names
    document.css('[data-role="light-row"]').map { |row| row["data-light"] }
  end

  def fail_request(light)
    light.run { raise "Service unavailable" }
  rescue RuntimeError, Stoplight::Error::RedLight
    nil
  end

  YELLOW_COOL_OFF_TIME = 1
  MAX_BREACH_ATTEMPTS = 5
  YELLOW_WAIT_TIMEOUT = 10

  def register_lights(system, table)
    rows = table.hashes

    lights = rows.map { |row| [row, system.register(row.fetch("Name"), **registration_options(row))] }
    lights.each { |row, light| breach_light(light) unless row.fetch("Color") == "green" }

    yellow_lights = lights.select { |row, _| row.fetch("Color") == "yellow" }.map { |_, light| light }
    wait_until_yellow(yellow_lights) unless yellow_lights.empty?

    lights.each { |row, light| verify_color(light, row.fetch("Color")) }
  end

  def registration_options(row)
    (row.fetch("Color") == "yellow") ? {cool_off_time: YELLOW_COOL_OFF_TIME} : {}
  end

  def breach_light(light)
    MAX_BREACH_ATTEMPTS.times do
      break if light.color == Stoplight::Color::RED

      fail_request(light)
    end
  end

  def wait_until_yellow(lights)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + YELLOW_WAIT_TIMEOUT
    until lights.all? { |light| light.color == Stoplight::Color::YELLOW }
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        raise "expected #{lights.map(&:name)} to turn yellow within #{YELLOW_WAIT_TIMEOUT}s, " \
          "but their colors are #{lights.map(&:color)}"
      end
      sleep(0.1)
    end
  end

  def verify_color(light, expected_color)
    actual_color = light.color.to_s
    raise "expected #{light.name.inspect} to be #{expected_color}, but it is #{actual_color}" if actual_color != expected_color
  end
end
