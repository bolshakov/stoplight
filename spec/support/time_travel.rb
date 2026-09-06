# frozen_string_literal: true

module Stoplight
  module TimeTravel
    STACK_KEY = "stoplight:test_now_ms_stack"
    LUA_PATH = File.expand_path("lua", __dir__)

    class << self
      # LUA_PATH must stay first: the first now.lua on the path wins, and only that one reads STACK_KEY.
      def scripts_path
        [LUA_PATH, *Infrastructure::Redis::Storage::Scripting.default_scripts_path]
      end

      def freeze(time = Time.now)
        if block_given?
          Timecop.freeze(time) do
            redis_time_ms = Time.now.to_f * 1000.0
            redis.rpush(STACK_KEY, redis_time_ms)
            begin
              yield
            ensure
              redis.rpop(STACK_KEY)
            end
          end
        else
          redis.del(STACK_KEY)
          Timecop.freeze(time)
          redis_time_ms = Time.now.to_f * 1000.0
          redis.rpush(STACK_KEY, redis_time_ms)
        end
      end

      def return
        redis.del(STACK_KEY)
        Timecop.return
      end

      private

      def redis
        @redis ||= Redis.new
      end
    end
  end
end
