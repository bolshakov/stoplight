# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Storage
      module Redis
        # Redis-backed state storage for a single circuit breaker.
        #
        # Manages circuit breaker state transitions using Redis hashes and Lua scripts
        # for atomic operations. Ensures notification deduplication across distributed
        # processes - when multiple processes detect the same circuit condition,
        # only one will receive +true+ from transition methods.
        #
        # All state is stored in a single Redis hash with fields:
        # - +locked_state+: forced lock (UNLOCKED, LOCKED_GREEN, LOCKED_RED)
        # - +breached_at+: timestamp (float) when circuit opened
        # - +recovery_scheduled_after+: timestamp (float) when recovery probe allowed
        # - +recovery_started_at+: timestamp (float) when recovery probe began
        #
        # @example Basic usage
        #   state = State.new(
        #     clock: SystemClock.new,
        #     redis: Redis.new,
        #     scripting: Scripting.new(redis:),
        #     key_space: KeySpace.build(light_name: "payments", system_name: "main"),
        #     cool_off_time: 60
        #   )
        #
        #   # Multiple processes may call this concurrently
        #   if state.transition_to_color(Domain::Color::RED)
        #     # Only one process reaches here - send notification
        #     notifier.notify("payments", :opened)
        #   end
        #
        # @note Thread safety is guaranteed by Redis's single-threaded execution model
        #   and the use of Lua scripts for atomic multistep operations.
        #
        # @see Stoplight::Memory::State for the in-memory equivalent
        # @see Stoplight::Domain::StateSnapshot for the structure of state snapshots
        #
        class State < Domain::Storage::State
          # @!attribute redis
          #   @return [::Redis | ConnectionPool<::Redis>]
          private attr_reader :redis

          # @!attribute scripting
          #   @return [Stoplight::Infrastructure::DataStore::Redis::Scripting]
          private attr_reader :scripting

          # @!attribute key_space
          #   @return [Stoplight::Infrastructure::Storage::Redis::KeySpace]
          private attr_reader :key_space

          # @!attribute clock
          #   @return [Stoplight::Domain::Clock]
          private attr_reader :clock

          # @!attribute cool_off_time
          #   @return [Integer]
          private attr_reader :cool_off_time

          # @!attribute state_key
          #   @return [String]
          private attr_reader :state_key

          # @param clock [Stoplight::Domain::Clock]
          # @param redis [::Redis, ConnectionPool<::Redis>]
          # @param scripting [Stoplight::Infrastructure::DataStore::Redis::Scripting]
          # @param key_space [Stoplight::Infrastructure::DataStore::Redis::KeySpace]
          # @param cool_off_time [Integer]
          def initialize(clock:, redis:, scripting:, key_space:, cool_off_time:)
            @redis = redis
            @scripting = scripting
            @key_space = key_space
            @clock = clock
            @cool_off_time = cool_off_time

            @state_key = key_space.key(:state)
          end

          # @param state [String]
          # @return [String]
          def set_state(state)
            redis.with do |client|
              client.hset(state_key, "locked_state", state)
            end
            state
          end

          # @return [Stoplight::Domain::StateSnapshot]
          def state_snapshot
            breached_at_raw, locked_state, recovery_scheduled_after_raw, recovery_started_at_raw = redis.with do |client|
              client.hmget(state_key, :breached_at, :locked_state, :recovery_scheduled_after, :recovery_started_at)
            end

            Domain::StateSnapshot.new(
              breached_at: breached_at_raw && clock.at(breached_at_raw.to_f),
              locked_state: locked_state || Domain::State::UNLOCKED,
              recovery_scheduled_after: recovery_scheduled_after_raw && clock.at(recovery_scheduled_after_raw.to_f),
              recovery_started_at: recovery_started_at_raw && clock.at(recovery_started_at_raw.to_f),
              time: clock.current_time
            )
          end

          # @return [void]
          def clear
            redis.with do |client|
              client.del(state_key)
            end
          end

          def transition_to_color(color)
            case color
            when Domain::Color::GREEN
              transition_to_green
            when Domain::Color::YELLOW
              transition_to_yellow
            when Domain::Color::RED
              transition_to_red
            else
              raise ArgumentError, "Invalid color: #{color}"
            end
          end

          # Transitions to GREEN state and ensures only one notification
          #
          # @return [Boolean] true if this is the first instance to detect this transition
          private def transition_to_green
            became_green = scripting.call(
              :transition_to_green,
              args: [clock.current_time.to_f],
              keys: [state_key]
            )
            became_green == 1
          end

          # Transitions to YELLOW (recovery) state and ensures only one notification
          #
          # @return [Boolean] true if this is the first instance to detect this transition
          private def transition_to_yellow
            became_yellow = scripting.call(
              :transition_to_yellow,
              args: [clock.current_time.to_f],
              keys: [state_key]
            )
            became_yellow == 1
          end

          # Transitions to RED state and ensures only one notification
          #
          # @return [Boolean] true if this is the first instance to detect this transition
          private def transition_to_red
            current_ts = clock.current_time.to_f
            recovery_scheduled_after_ts = current_ts + cool_off_time

            became_red = scripting.call(
              :transition_to_red,
              args: [current_ts, recovery_scheduled_after_ts],
              keys: [state_key]
            )

            became_red == 1
          end
        end
      end
    end
  end
end
