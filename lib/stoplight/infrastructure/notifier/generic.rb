# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Notifier
      # The Generic module provides a reusable implementation for notifiers in Stoplight.
      # It includes a formatter for generating notification messages and defines the `notify` method.
      #
      # @example Custom Notifier Implementation and Usage
      #     # Custom notifier that writes notifications to a file
      #     class FileNotifier < Stoplight::Domain::StateTransitionNotifier
      #       include Stoplight::Notifier::Generic
      #
      #       def initialize(file_path)
      #         @file = File.open(file_path, 'a')
      #         super(@file)
      #       end
      #
      #       private
      #
      #       # Writes the notification message to the file
      #       def put(message)
      #         @file.puts(message)
      #       end
      #     end
      #
      #     # Usage example
      #     # Create a custom notifier that writes to 'stoplight.log'
      #     notifier = FileNotifier.new('stoplight.log')
      #
      #     # Configure Stoplight to use the custom notifier
      #     Stoplight.configure do |config|
      #       config.notifiers += [notifier]
      #     end
      #
      #     # Create a stoplight and trigger a state change
      #     light = Stoplight('example-light')
      #     light.run { raise 'Simulated failure' } rescue nil
      #     light.run { raise 'Simulated failure' } rescue nil
      #     light.run { raise 'Simulated failure' } rescue nil
      #
      module Generic # rubocop:disable Style/Documentation
        # @!attribute [r] formatter
        #   @return [Proc] The formatter used to generate notification messages.
        #   @see Stoplight::Default::FORMATTER
        # @dynamic formatter
        attr_reader :formatter

        DEFAULT_FORMATTER = lambda do |light, from_color, to_color, error|
          words = ["Switching", light.name, "from", from_color, "to", to_color]
          words += ["because", error.class, error.message] if error
          words.join(" ")
        end
        public_constant :DEFAULT_FORMATTER

        # @param object [Object] The object used by the notifier (e.g., a logger or external service).
        # @param formatter [Proc, nil] A custom formatter for generating notification messages.
        #   If no formatter is provided, the default formatter is used.
        def initialize(object, formatter = nil)
          @object = object
          @formatter = formatter || DEFAULT_FORMATTER
        end

        # Sends a notification when a Stoplight changes state.
        #
        # @param light [Light] The Stoplight instance triggering the notification.
        # @param from_color [String] The previous state color of the Stoplight.
        # @param to_color [String] The new state color of the Stoplight.
        # @param error [Exception, nil] The error (if any) that caused the state change.
        # @return [String] The formatted notification message.
        def notify(light, from_color, to_color, error)
          message = formatter.call(light, from_color, to_color, error)
          put(message)
          message
        end

        private

        # Processes the notification message.
        #
        # @param message [String] The notification message to be processed.
        # @raise [NotImplementedError] If the method is not implemented in a subclass.
        # :nocov:
        def put(message)
          raise NotImplementedError
        end
        # :nocov:
      end
    end
  end
end
