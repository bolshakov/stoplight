# frozen_string_literal: true

module Stoplight
  class Admin
    module Helpers
      COLORS = [
        Color::GREEN,
        Color::YELLOW,
        Color::RED
      ].freeze

      def dependencies(system)
        Dependencies.new(system:)
      end

      def system_url(system_id, path)
        path = "/#{path}" unless path.starts_with?("/")

        url("/systems/#{system_id}#{path}")
      end

      def asset_path(name)
        url("/#{name}?v=#{ASSET_DIGESTS.fetch(name)}")
      end

      # A read-only control keeps its place but loses its href, so there is nothing to follow
      # and nothing to copy out of the page. aria-disabled carries that state to assistive
      # technology, which the styling alone does not reach.
      #
      # @example The same control, writable and read-only
      #   control_attributes(url("/light-id/lock?color=red"), verb: "patch")
      #   # => href="http://localhost/light-id/lock?color=red" data-turbo-method="patch"
      #
      #   # once `set :read_only, true`
      #   # => aria-disabled="true" title="Disabled in read-only mode"
      #
      # @param confirm [String, nil] message to confirm before following the link
      # @param verb [String] the HTTP verb Turbo should use to follow the link
      def control_attributes(href, confirm: nil, verb: "post")
        return %(aria-disabled="true" title="Disabled in read-only mode") if settings.read_only?

        [
          %(href="#{CGI.escapeHTML(href)}"),
          %(data-turbo-method="#{verb}"),
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

      def find_system(system_id)
        settings.systems.find(-> { halt 404 }) do |system|
          system.config.id == system_id
        end
      end
    end
  end
end
