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
            @shas = Hash.new do |hash, script_name|
              hash[script_name] = Digest::SHA1.hexdigest(resolve_source(script_name))
            end
          end

          def call(script_name, keys: [], args: [])
            retried = false

            begin
              @redis.then do |client|
                client.evalsha(@shas[script_name], keys: keys.map(&:to_s), argv: args.map(&:to_s))
              end
            rescue ::Redis::CommandError => error
              if error.message.include?("NOSCRIPT") && !retried
                retried = true
                reload_script(script_name)
                retry
              else
                raise error
              end
            end
          end

          private

          def reload_script(script_name)
            warn "Stoplight is unable to find the script '#{script_name}' in Redis's script cache. Reloading and retrying..."
            @redis.then { |client| client.script(:load, resolve_source(script_name)) }
          end

          # Redis's Lua sandbox has no `require`, so an included script is spliced in as source text.
          def resolve_source(script_name)
            source = File.read(File.join(@scripts_root, "#{script_name}.lua"))
            source.gsub(INCLUDE_DIRECTIVE) { resolve_source(T.must(Regexp.last_match(1))) }
          end
        end
      end
    end
  end
end
