# frozen_string_literal: true

# The ConfigureLightWorld module provides methods to configure a Stoplight::Light
# instance with various options.
module ConfigureLightWorld
  def configure_light(light, table) # rubocop:disable Metrics/MethodLength
    table.rows_hash.each_pair do |option, value|
      light = case option
      when "Skipped Errors"
        configure_skipped_errors(light, value)
      when "Threshold"
        configure_threshold(light, value)
      when "Cool Off Time"
        configure_cool_off_time(light, value)
      when "Window Size"
        configure_window_size(light, value)
      else
        raise ArgumentError, "Unknown option: #{option}"
      end
    end
    light
  end

  def configure_window_size(light, value)
    light.with(window_size: value.to_f)
  end

  def configure_cool_off_time(light, value)
    light.with(cool_off_time: value.to_f)
  end

  def configure_threshold(light, value)
    light.with(threshold: value.to_i)
  end

  def configure_skipped_errors(light, value)
    exception_classes = value.split(",").map(&:strip).map { |name| Object.const_get(name) }
    light.with(skipped_errors: exception_classes)
  end
end
