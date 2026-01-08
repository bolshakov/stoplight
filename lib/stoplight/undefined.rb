# frozen_string_literal: true

module Stoplight
  # Singleton representing an undefined/not-provided argument.
  #
  # Distinct from nil, which may be a valid configured value.
  # Used with keyword arguments to detect when a parameter
  # wasn't passed vs. explicitly set to nil.
  # @api private
  class Undefined
    include Singleton

    def inspect = "UNDEFINED"
    alias_method :to_s, :inspect
  end
end
