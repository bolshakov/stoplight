# frozen_string_literal: true

require "ostruct"

module Stoplight
  # @!attribute [rw] cool_off_time
  #   @return [Float]
  #
  # @!attribute [rw] data_store
  #   @return [DataStore::Base]
  #
  # @!attribute [rw] error_notifier
  #   @return [Proc]
  #
  # @!attribute [rw] notifiers
  #   @return [Array<Notifier::Base>]
  #
  # @!attribute [rw] threshold
  #   @return [Integer]
  #
  # @!attribute [rw] window_size
  #   @return [Integer, Float]
  #
  # @!attribute [rw] tracked_errors
  #   @return [Array<StandardError>]
  #
  # @!attribute [rw] skipped_errors
  #   @return [Array<StandardError>]
  class ProgrammaticConfig < OpenStruct
  end
end
