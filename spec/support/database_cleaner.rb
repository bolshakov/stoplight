# frozen_string_literal: true

require 'redis'
require 'database_cleaner/redis'

cleaning_strategy = DatabaseCleaner::Redis::Deletion.new(only: ["#{Stoplight::DataStore::Redis::KEY_PREFIX}*"])
DatabaseCleaner.strategy = cleaning_strategy

RSpec.shared_context :redis, :redis do
  let(:redis) { Redis.new(url: ENV.fetch('STOPLIGHT_REDIS_URL', 'redis://127.0.0.1:6379/0')) }

  before do
    DatabaseCleaner[:redis].db = redis
    DatabaseCleaner.clean_with(:deletion)
  end

  around do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end

RSpec.configure do |config|
  config.include_context :redis, include_shared: true
end
