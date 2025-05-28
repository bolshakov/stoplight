# frozen_string_literal: true

module Stoplight
  class Admin
    module Actions
      # @abstract
      class Action
        # @!attribute lights_repository
        #   @return [Stoplight::Admin::LightsRepository]
        attr_reader :lights_repository
        private :lights_repository

        # @return lights_repository [Stoplight::Admin::LightsRepository]
        def initialize(lights_repository:)
          @lights_repository = lights_repository
        end

        def call(params)
          raise NotImplementedError
        end
      end
    end
  end
end
