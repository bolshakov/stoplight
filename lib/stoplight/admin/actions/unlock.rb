# frozen_string_literal: true

module Stoplight
  class Admin
    module Actions
      # This action unlocks light
      class Unlock < Action
        def call(params)
          Array(params[:ids]).each do |name|
            @lights_repository.unlock(name)
          end
        end
      end
    end
  end
end
