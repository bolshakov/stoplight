# frozen_string_literal: true

module Stoplight
  module Wiring
    # Empty notifiers prevent notification loops; inherited Memory data store prevents infinite recursion if Redis is down.
    FailSafeConfig = DefaultConfig.with(
      notifiers: [],
      data_store: DataStore::Memory.new
    )
  end
end
