# frozen_string_literal: true

module Stoplight
  module TrafficRecovery
    Decision = Data.define(:decision)
    GREEN = Decision.new("green")
    YELLOW = Decision.new("yellow")
    RED = Decision.new("red")
    PASS = Decision.new("pass")
  end
end
