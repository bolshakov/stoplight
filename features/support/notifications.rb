# frozen_string_literal: true

# A helper class that collects stoplight transition notifications
# captured during the test run.
class Notifications
  def initialize
    @notifications = Hash.new { |hash, key| hash[key] = [] }
  end

  def add_notification(name, from_color, to_color)
    @notifications[name] << [from_color, to_color]
  end

  def last_notification(name)
    @notifications[name].last
  end
end

# A stoplight notifier that captures notifications
class TestNotifier < Stoplight::Notifier::Base
  def initialize(notifications)
    @notifications = notifications
  end

  def notify(config, from_color, to_color, _error)
    @notifications.add_notification(config.name, from_color, to_color)
  end
end
