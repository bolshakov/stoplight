# This file is used by Rack-based servers to start the application.

require "bundler/setup"

require "redis" # Uses ENV['REDIS_URL']
require "sinatra"
require "stoplight"
require "stoplight/admin"

redis = Redis.new

Stoplight::Admin.configure do
  set :data_store, Stoplight::DataStore::Redis.new(redis)
  set :environment, :production
end

run Stoplight::Admin

