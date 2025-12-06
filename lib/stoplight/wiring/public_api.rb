# frozen_string_literal: true

module Stoplight
  module Wiring
    # Public API facade for backward compatibility and convenience
    # @api public
    module PublicApi
      # Aliases for domain concepts
      Color = Domain::Color
      Error = Domain::Error
      State = Domain::State

      # Namespace aliases for data stores
      module DataStore
        Base = Stoplight::Wiring::DataStore::Base
        Redis = Stoplight::Wiring::DataStore::Redis
        Memory = Stoplight::Wiring::DataStore::Memory
      end

      # Namespace aliases for notifiers
      module Notifier
        Base = Domain::StateTransitionNotifier
        Generic = Infrastructure::Notifier::Generic
        IO = Infrastructure::Notifier::IO
        Logger = Infrastructure::Notifier::Logger
      end
    end
  end
end
