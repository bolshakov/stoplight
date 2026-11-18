# frozen_string_literal: true

Given("an admin panel backed by a persistent data store") do
  data_store = Stoplight::DataStore::Redis.new(redis)
  Stoplight.configure(trust_me_im_an_engineer: true) do |config|
    config.data_store = data_store
    config.notifiers = []
  end
end

Given("an admin panel in read-only mode") do
  pending
end

Given("STOPLIGHT_ADMIN_READ_ONLY is set to {string}") do |value|
  pending
end

Given("no systems are configured") do
  pending
end

Given("a system {string} is configured") do |system_name|
  configure_system(system_name)
end

Given("the following systems are configured:") do |table|
  table.hashes.each { |row| configure_system(row.fetch("Name")) }
end

Given("a system {string} configured with:") do |system_name, table|
  pending
end

Given("a {light} exists") do |light|
  system_for(light).register(light.name)
end

Given("a {color} {light} exists") do |color, light|
  cool_off_time = (color == Stoplight::Color::YELLOW) ? AdminWorld::YELLOW_COOL_OFF_TIME : nil
  entity = system_for(light).register(light.name, **(cool_off_time ? {cool_off_time:} : {}))

  breach_light(entity) unless color == Stoplight::Color::GREEN
  wait_until_yellow([entity]) if color == Stoplight::Color::YELLOW
  verify_color(entity, color.to_s)
end

Given("a {light} configured with:") do |light, table|
  options = {cool_off_time: AdminWorld::YELLOW_COOL_OFF_TIME}

  table.rows_hash.each do |key, value|
    case key
    when "Cool Off Time"
      options[:cool_off_time] = value.to_i
    when "Recovery Threshold"
      options[:recovery_threshold] = value.to_i
    else
      raise "unsupported configuration key: #{key.inspect}"
    end
  end

  system_for(light).register(light.name, **options)
end

Given("the following lights exist:") do |table|
  register_lights(Stoplight.__stoplight__default_system, table)
end

Given("the following lights in system {string} exist:") do |system_name, table|
  register_lights(system_named(system_name), table)
end

Given("no lights exist") do
end

Given("no lights in system {string} exist") do |_system_name|
end

Given("{int} {color} lights exist") do |count, color|
  pending
end

Given("{light} enters {color} state") do |light, color|
  pending("entering #{color} state") unless [Stoplight::Color::RED, Stoplight::Color::YELLOW].include?(color)

  entity = find_light(light)
  fail_request(entity) until entity.color == Stoplight::Color::RED
  wait_until_yellow([entity]) if color == Stoplight::Color::YELLOW
end

Given("{light} is locked to {color}") do |light, color|
  find_light(light).lock(color)
end

Given("{light} last failed with {string}") do |light, error_message|
  config = config_for(light)
  storage = system_for(light).__stoplight__storage
  entity = find_light(light)

  case entity.color
  when Stoplight::Color::RED
    storage.delete(config)
    breach_light(entity, error_message)
  when Stoplight::Color::YELLOW
    storage.send(:recovery_metrics_store, config).record_failure(RuntimeError.new(error_message))
  else
    raise "#{light.name.inspect} must be red or yellow before recording a last error, got #{entity.color}"
  end
end

Given("a request to {light} fails") do |light|
  fail_request(find_light(light))
end

Given("{light} has recorded {int} consecutive error(s)") do |light, count|
  pending
end

Given("{light} has recorded {int} error(s) out of {int} request(s)") do |light, errors, requests|
  pending
end

Given("{light} has recorded:") do |light, table|
  pending
end

Given("{light} has never been called") do |light|
  pending
end

Given("{light} has been removed") do |light|
  pending
end

Given("{int} second(s) have elapsed") do |seconds|
  sleep(seconds)
end
