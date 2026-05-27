# frozen_string_literal: true

module Stoplight
  module Wiring
    FailSafeConfig = DefaultConfig.with(notifiers: [])
  end
end
