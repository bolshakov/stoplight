# frozen_string_literal: true

require "singleton"

module Stoplight
  module Types
    UNDEFINED = Undefined.instance
    def self.undefined = UNDEFINED

    # Asserts a value is non-nil, returning it with a narrowed type.
    #
    # Use this to satisfy Steep's flow typing when you know a nilable value
    # must be present. Prefer this over type assertions (#: Type) since it
    # provides runtime validation.
    #
    # @example Validating required configuration
    #   @window_size = T.must(config.window_size)
    #
    # @raise [TypeError] if value is nil
    # @return [T] the non-nil value
    #
    def self.must(value)
      case value
      when nil
        raise TypeError, "must not have nil value"
      else
        value
      end
    end
  end
end
