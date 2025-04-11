# frozen_string_literal: true

module Stoplight
  module Default
    DATA_STORE = Light::Config::DEFAULT_DATA_STORE
    FORMATTER = Stoplight::Notifier::Generic::DEFAULT_FORMATTER

    warn "You're using the deprecated constants in Stoplight::Default. Please consult the upgrade guide for more information."
  end
end
