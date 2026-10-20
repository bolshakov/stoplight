# frozen_string_literal: true

module Stoplight
  class Admin
    class Panel
      module Helpers
        STATE_TEMPLATES = {
          [Stoplight::Color::GREEN, Stoplight::State::UNLOCKED] => :"states/_green",
          [Stoplight::Color::GREEN, Stoplight::State::LOCKED_GREEN] => :"states/_locked_green",
          [Stoplight::Color::YELLOW, Stoplight::State::UNLOCKED] => :"states/_yellow",
          [Stoplight::Color::RED, Stoplight::State::UNLOCKED] => :"states/_red",
          [Stoplight::Color::RED, Stoplight::State::LOCKED_RED] => :"states/_locked_red"
        }.freeze

        def dependencies
          Dependencies.new(system: current_system)
        end

        def selected_light(lights)
          lights.first
        end

        def find_light(lights, light_id)
          lights.find(-> { halt 404 }) { |light| light.id == light_id }
        end

        def state_template_for(light)
          STATE_TEMPLATES.fetch([light.color, light.lock_state])
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

        def turbo_frame_request?
          !!request.env["HTTP_TURBO_FRAME"]
        end
      end
    end
  end
end
