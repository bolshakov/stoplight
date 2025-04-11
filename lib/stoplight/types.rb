# frozen_string_literal: true

require "dry-types"

module Stoplight
  class Types
    include Dry.Types()

    DataStore = Types.Instance(Stoplight::DataStore::Base)
    ErrorNotifier = Types.Interface(:call)
    Notifier = Types::Instance(Stoplight::Notifier::Base)
    TrackedError = Types.Instance(StandardError.class)
    SkippedError = Types.Instance(Exception.class)
  end
end
