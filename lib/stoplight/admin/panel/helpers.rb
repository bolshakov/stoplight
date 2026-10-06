# frozen_string_literal: true

module Stoplight
  class Admin
    class Panel
      module Helpers
        def dependencies
          Dependencies.new(system: current_system)
        end

        def system_url(system_id, path)
          url("/systems/#{system_id}#{path}", false)
        end

        def asset_path(name)
          url("/#{name}?v=#{ASSET_DIGESTS.fetch(name)}", false)
        end

        def find_system(system_id)
          settings.systems.find(-> { halt 404 }) do |system|
            system.config.id == system_id
          end
        end

        def current_system_id
          T.must(params[:system_id])
        end

        def current_system
          find_system(current_system_id)
        end
      end
    end
  end
end
