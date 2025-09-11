# frozen_string_literal: true

# The ConfigureLightWorld module provides methods to configure a Stoplight::Light
# instance with various options.
module ConfigureLightWorld
  def configure_light(light, table) # rubocop:disable Metrics/MethodLength
    @with_configuration = {}
    table.rows_hash.each_pair do |option, value|
      case option
      when "Skipped Errors"
        configure_skipped_errors(value)
      when "Threshold"
        configure_threshold(value)
      when "Recovery Threshold"
        configure_recovery_threshold(value)
      when "Cool Off Time"
        configure_cool_off_time(value)
      when "Window Size"
        configure_window_size(value)
      when "Traffic Control"
        configure_traffic_control(value)
      else
        raise ArgumentError, "Unknown option: #{option}"
      end
    end
    light.with(**@with_configuration).tap do
      @with_configuration = nil
    end
  end

  def configure_traffic_control(value)
    @with_configuration[:traffic_control] = value.sub(" ", "_").downcase.to_sym
  end

  def configure_window_size(value)
    @with_configuration[:window_size] = value.to_f
  end

  def configure_cool_off_time(value)
    @with_configuration[:cool_off_time] = value.to_f
  end

  def configure_threshold(value)
    @with_configuration[:threshold] = if value.include?(".")
      value.to_f
    else
      value.to_i
    end
  end

  def configure_recovery_threshold(value)
    @with_configuration[:recovery_threshold] = value.to_i
  end

  def configure_skipped_errors(value)
    exception_classes = value.split(",").map(&:strip).map { |name| Object.const_get(name) }
    @with_configuration[:skipped_errors] = exception_classes
  end
end
