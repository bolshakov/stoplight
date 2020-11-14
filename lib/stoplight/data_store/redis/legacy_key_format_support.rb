module Stoplight
  module DataStore
    class Redis
      module LegacyKeyFormatSupport
        def color
          if data_store.is_a?(Stoplight::DataStore::Redis) && legacy_key_format?(self)
            data_store.migrate_failures(self)
          else
            super
          end
        end
      end
    end
  end
end
