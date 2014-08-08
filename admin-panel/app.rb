# coding: utf-8

require 'haml'
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

post '/lock' do
  [*params[:names]].each { |l| lock(l) }
  redirect to('/')
end

post '/unlock' do
  [*params[:names]].each { |l| unlock(l) }
  redirect to('/')
end

post '/green' do
  [*params[:names]].each { |l| green(l) }
  redirect to('/')
end

post '/red' do
  [*params[:names]].each { |l| red(l) }
  redirect to('/')
end

###

def lights
  Stoplight::Light.names
    .map { |name| light_info(name) }
    .sort_by { |light| light_sort_key(light) }
end

def light_info(light)
  green = Stoplight::Light.green?(light)
  attempts = green ? 0 : Stoplight::Light.data_store.attempts(light)

  {
    name: light,
    green: green,
    attempts: attempts,
    locked: locked?(light)
  }
end

def light_sort_key(light)
  [light[:green] ? 1 : 0,
   light[:attempts] * -1,
   light[:name]]
end

def locked?(light_name)
  [Stoplight::DataStore::STATE_LOCKED_GREEN,
   Stoplight::DataStore::STATE_LOCKED_RED]
    .include?(Stoplight::Light.data_store.state(light_name))
end

# rubocop:disable Style/MethodLength
def stat_params(ls)
  total_count = ls.size
  success_count = ls.count { |l| l[:green] }
  failure_count = total_count - success_count

  if total_count > 0
    failure_percentage = (100.0 * failure_count / total_count).ceil
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
# rubocop:enable Style/MethodLength

def lock(light)
  new_state =
    if Stoplight::Light.green?(light)
      Stoplight::DataStore::STATE_LOCKED_GREEN
    else
      Stoplight::DataStore::STATE_LOCKED_RED
    end

  Stoplight::Light.data_store.set_state(light, new_state)
end

def unlock(light)
  new_state = Stoplight::DataStore::STATE_UNLOCKED
  Stoplight::Light.data_store.set_state(light, new_state)
end

def green(light)
  if Stoplight::Light.data_store.state(light) ==
      Stoplight::DataStore::STATE_LOCKED_RED
    new_state = Stoplight::DataStore::STATE_LOCKED_GREEN
    Stoplight::Light.data_store.set_state(light, new_state)
  else
    Stoplight::Light.data_store.clear_failures(light)
  end

  Stoplight::Light.data_store.clear_attempts(light)
end

def red(light)
  new_state = Stoplight::DataStore::STATE_LOCKED_RED
  Stoplight::Light.data_store.set_state(light, new_state)
end
