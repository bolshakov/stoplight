# frozen_string_literal: true

module Stoplight
  module Domain
    module TrafficRecovery
      Decision = Data.define(:decision)
      GREEN = Decision.new("green")
      YELLOW = Decision.new("yellow")
      RED = Decision.new("red")
    end
  end
end
