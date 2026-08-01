# frozen_string_literal: true

module Stoplight
  class Admin
    module Actions
      # This action removes a light's metadata from Redis
      class Remove < Action
        def call(params)
          Array(params[:ids]).each do |name|
            @lights_repository.remove(name)
          end
        end
      end
    end
  end
end
