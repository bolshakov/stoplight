# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module DataStore
      class Redis
        # @api private
        class ScriptManager
          ScriptNotFound = Class.new(StandardError)

          # @!attribute redis
          #   @return [RedisClient]
          private attr_reader :redis

          # @!attribute scripts
          #   @return [{Symbol => String}]
          private attr_reader :scripts

          # @param redis [RedisClient]
          def initialize(redis:)
            @redis = redis
            @scripts = {}
          end

          # @param path [Symbol]
          # @param script_name [Symbol]
          # @return [String] SHA of the script
          def sha(path, script_name)
            # Race condition is possible but acceptable here
            # In the worst case scenario, we'll upload the same script twice
            scripts[[path, script_name]] ||= redis.then do |client|
              client.script("load", read_script(path, script_name))
            end
          end

          private def read_script(path, script_name)
            full_path = File.join(__dir__, path.to_s, "#{script_name}.lua")

            if File.exist?(full_path)
              File.read(full_path)
            else
              raise ScriptNotFound, full_path.to_s
            end
          end
        end
      end
    end
  end
end
