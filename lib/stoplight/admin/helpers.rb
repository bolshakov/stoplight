# frozen_string_literal: true

module Stoplight
  class Admin
    module Helpers
      COLORS = [
        GREEN = Stoplight::Color::GREEN,
        YELLOW = Stoplight::Color::YELLOW,
        RED = Stoplight::Color::RED
      ].freeze

      # @return [Stoplight::Admin::Dependencies]
      def dependencies
        if settings.data_store.is_a?(Stoplight::DataStore::Memory)
          raise "Stoplight Admin requires a persistent data store, but the current data store is Memory. " \
            "Please configure a different data store in your Stoplight configuration."
        end
        Dependencies.new(system: Stoplight.__stoplight__default_system)
      end

      def asset_path(name)
        url("/#{name}?v=#{ASSET_DIGESTS.fetch(name)}")
      end

      # A read-only control keeps its place but loses its href, so there is nothing to follow
      # and nothing to copy out of the page. aria-disabled carries that state to assistive
      # technology, which the styling alone does not reach.
      #
      # @example The same control, writable and read-only
      #   control_attributes(url("/red?names=foo"))
      #   # => href="http://localhost/red?names=foo" data-turbo-method="post"
      #
      #   # once `set :read_only, true`
      #   # => aria-disabled="true" title="Disabled in read-only mode"
      #
      # @param confirm [String, nil] message to confirm before following the link
      def control_attributes(href, confirm: nil)
        return %(aria-disabled="true" title="Disabled in read-only mode") if settings.read_only?

        [
          %(href="#{CGI.escapeHTML(href)}"),
          %(data-turbo-method="post"),
          (%(data-turbo-confirm="#{CGI.escapeHTML(confirm)}") if confirm)
        ].compact.join(" ")
      end

      def time_ago_in_words(time)
        time_difference = Time.now.utc - time
        if time_difference < 1
          "just now"
        elsif time_difference < 60
          "#{time_difference.to_i}s ago"
        elsif time_difference < 3600
          "#{(time_difference / 60).to_i}m ago"
        elsif time_difference < 86400
          "#{(time_difference / 3600).to_i}h ago"
        else
          "#{(time_difference / 86400).to_i}d ago"
        end
      end
    end
  end
end
