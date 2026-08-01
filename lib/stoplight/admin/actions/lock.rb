# frozen_string_literal: true

module Stoplight
  class Admin
    module Actions
      # This action locks light
      class Lock < Action
        def call(params)
          Array(params[:ids]).each do |id|
            @lights_repository.lock(id)
          end
        end
      end
    end
  end
end
