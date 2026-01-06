# frozen_string_literal: true

require "singleton"

module Stoplight
  module Types
    # Singleton representing an undefined/not-provided argument.
    #
    # Distinct from nil, which may be a valid configured value.
    # Used with keyword arguments to detect when a parameter
    # wasn't passed vs. explicitly set to nil.
    class Undefined
      include Singleton

      def inspect = "UNDEFINED"
      alias_method :to_s, :inspect
    end

    def self.undefined = Undefined.instance

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
      if value.nil?
        raise TypeError, "must not have nil value"
      else
        value
      end
    end
  end
end
