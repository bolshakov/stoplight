# frozen_string_literal: true

module Stoplight
  class Admin
    module Actions
      # This action removes a light's metadata from Redis
      class Remove < Action
        def call(params)
          light_names(params).each do |name|
            @lights_repository.remove(name)
          end
        end

        private def light_names(params)
          Array(params[:names])
            .map { |name| CGI.unescape(name) }
        end
      end
    end
  end
end
