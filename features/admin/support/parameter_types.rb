# frozen_string_literal: true

require "stoplight"

LightReference = Data.define(:name, :system_name)

ParameterType(
  name: "color",
  regexp: /red|yellow|green/,
  transformer: ->(name) { Stoplight::Color.const_get(name.upcase) }
)

ParameterType(
  name: "state",
  regexp: /unlocked|locked_green|locked_red/,
  transformer: ->(name) { Stoplight::State.const_get(name.upcase) }
)

ParameterType(
  name: "light",
  regexp: /light "([^"]+)"(?: in system "([^"]+)")?/,
  transformer: ->(name, system_name = nil) { LightReference.new(name:, system_name:) }
)
