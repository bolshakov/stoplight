# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Redis
      module Storage
        class Scripting
          SCRIPTS_ROOT = __dir__ => String
          private_constant :SCRIPTS_ROOT

          INCLUDE_DIRECTIVE = /^--\s*@include\s+([\w\-\/]+)$/
          private_constant :INCLUDE_DIRECTIVE

          class << self
            def default_scripts_root = SCRIPTS_ROOT
          end

          def initialize(redis:, scripts_root: self.class.default_scripts_root)
            @scripts_root = scripts_root
            @redis = redis
            @shas = {}
          end

          def call(script_name, keys: [], args: [])
            redis.then do |client|
              client.evalsha(script_sha(script_name), keys: keys.map(&:to_s), argv: args.map(&:to_s))
            end
          rescue ::Redis::CommandError => error
            if error.message.include?("NOSCRIPT")
              reload_script(script_name)
              retry
            else
              raise
            end
          end

          private

          attr_reader :scripts_root
          attr_reader :redis
          attr_reader :shas

          def reload_script(script_name)
            shas.delete(script_name)
            script_sha(script_name)
          end

          def script_sha(script_name)
            if shas.key?(script_name)
              shas[script_name]
            else
              shas[script_name] = redis.then { |client| client.script(:load, resolve_source(script_name)) }
            end
          end

          # Redis's Lua sandbox has no `require`, so an included script is spliced in as source text.
          def resolve_source(script_name)
            source = File.read(File.join(scripts_root, "#{script_name}.lua"))
            source.gsub(INCLUDE_DIRECTIVE) { resolve_source(T.must(Regexp.last_match(1))) }
          end
        end
      end
    end
  end
end
