# frozen_string_literal: true

# The ConfigureLightWorld module provides methods to configure a Stoplight::Light
# instance with various options.
module ConfigureLightWorld
  def configure_light(name, table = nil)
    factory_method = ENV.fetch("STOPLIGHT_LIGHT_CREATION", "Stoplight()")
    case factory_method
    when "Stoplight()"
      Stoplight(name, **collect_settings(table))
    when "System#register"
      system.register(name, **collect_settings(table))
    else
      raise ArgumentError, "unexpected light creation method: `#{factory_method}`"
    end
  end

  def collect_settings(table)
    return {} unless table
    settings = {}
    table.rows_hash.each_pair do |option, value|
      case option
      when "Tracked Errors"
        configure_tracked_errors(value, settings)
      when "Skipped Errors"
        configure_skipped_errors(value, settings)
      when "Threshold"
        configure_threshold(value, settings)
      when "Recovery Threshold"
        configure_recovery_threshold(value, settings)
      when "Cool Off Time"
        configure_cool_off_time(value, settings)
      when "Window Size"
        configure_window_size(value, settings)
      when "Traffic Control"
        configure_traffic_control(value, settings)
      else
        raise ArgumentError, "Unknown option: #{option}"
      end
    end
    settings
  end

  def configure_traffic_control(value, settings)
    settings[:traffic_control] = value.sub(" ", "_").downcase.to_sym
  end

  def configure_window_size(value, settings)
    settings[:window_size] = if value == "nil"
      nil
    else
      value.to_f
    end
  end

  def configure_cool_off_time(value, settings)
    settings[:cool_off_time] = value.to_f
  end

  def configure_threshold(value, settings)
    settings[:threshold] = if value.include?(".")
      value.to_f
    else
      value.to_i
    end
  end

  def configure_recovery_threshold(value, settings)
    settings[:recovery_threshold] = value.to_i
  end

  def configure_tracked_errors(value, settings)
    exception_classes = value.split(",").map(&:strip).map { |name| Object.const_get(name) }
    settings[:tracked_errors] = exception_classes
  end

  def configure_skipped_errors(value, settings)
    exception_classes = value.split(",").map(&:strip).map { |name| Object.const_get(name) }
    settings[:skipped_errors] = exception_classes
  end
end
