# frozen_string_literal: true

require "digest"

module Stoplight
  module Domain
    # Helper to generate light/systems ids
    module Id
      # Derives id from a string
      def self.for(name) = T.must(Digest::SHA256.hexdigest(name)[0, 12])
    end
  end
end
