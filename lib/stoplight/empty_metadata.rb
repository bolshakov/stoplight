# frozen_string_literal: true

module Stoplight
  class EmptyMetadata < Metadata
    def initialize(current_time: Time.now)
      super
    end
  end
end
