# This file is used by Rack-based servers to start the application.

require "bundler/setup"

require "redis" # Uses ENV['REDIS_URL']
require "sinatra"
require "stoplight"
require "stoplight/admin"

redis = Redis.new

Stoplight.configure do |config|
  config.data_store = Stoplight::DataStore::Redis.new(redis)
end

Stoplight::Admin.set :environment, :production

run Stoplight::Admin
