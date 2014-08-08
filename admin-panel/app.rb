require 'sinatra'
require 'stoplight'

REDIS_URL = 'redis://localhost:6379'
DATA_STORE = Stoplight::DataStore::Redis.new(url: REDIS_URL)
Stoplight::Light.data_store DATA_STORE

get '/' do
  ls    = lights
  stats = stat_params(ls)

  haml :index, locals: stats.merge(lights: ls)
end

def lights
  Stoplight::Light.names.map do |name|
    {
      name: name,
      green: Stoplight::Light.green?(name),
      locked: locked?(name)
    }
  end.sort_by { |light| light_sort_key(light) }
end

def light_sort_key(light)
  [light[:green] ? 1 : 0, light[:name]]
end

def locked?(light_name)
  [Stoplight::DataStore::STATE_LOCKED_GREEN,
   Stoplight::DataStore::STATE_LOCKED_RED]
    .include?(Stoplight::Light.data_store.state(light_name))
end

def stat_params(ls)
  total_count = ls.size
  success_count = ls.select { |l| l[:green] }.size
  failure_count = total_count - success_count

  if total_count > 0
    failure_percentage = (failure_count.to_f / total_count.to_f * 100.0).ceil
    success_percentage = 100 - failure_percentage
  else
    failure_percentage = success_percentage = 0
  end

  {
    success_count: success_count,
    failure_count: failure_count,
    success_percentage: success_percentage,
    failure_percentage: failure_percentage
  }
end
