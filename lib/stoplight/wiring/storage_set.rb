# frozen_string_literal: true

module Stoplight
  module Wiring
    StorageSet = Data.define(
      :metrics_store,
      :recovery_metrics_store,
      :state_store,
      :recovery_lock_store
    )
  end
end
