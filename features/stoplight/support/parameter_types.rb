# frozen_string_literal: true

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
