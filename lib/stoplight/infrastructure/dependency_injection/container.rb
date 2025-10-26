# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module DependencyInjection
      # Generic dependency injection container for managing object dependencies.
      #
      # This is a low-level infrastructure component that provides the mechanism for
      # dependency resolution. It has no knowledge of Stoplight's domain concepts and
      # could theoretically be used in any Ruby application.
      #
      # The container supports three resolution strategies:
      #
      # 1. **Direct dependencies** - Pre-configured values stored in the container
      # 2. **Lazy initialization** - Dependencies that are transformed on first access
      # 3. **Factories** - Dependencies computed dynamically from other dependencies
      #
      # @example Basic usage with direct dependencies
      #   container = Container.new
      #   container.register(:logger, Logger.new)
      #   container.resolve(:logger) #=> #<Logger...>
      #
      # @example Using lazy initialization
      #   container.register(:redis, "redis://localhost:6379") do |url|
      #     Redis.new(url)
      #   end
      #   container.resolve(:redis) #=> #<Redis @connection_string="redis://localhost:6379">
      #
      # @example Using factories for computed dependencies
      #   container.register(:config, my_config)
      #   container.factory(:service) do
      #     MyService.new(config: resolve(:config))
      #   end
      #   container.resolve(:service) #=> #<MyService...>
      #
      # @example Building a container with DSL
      #   container = Container.define do
      #     register(:port, 3000)
      #     register(:host, "localhost")
      #
      #     factory(:server) do
      #       Server.new(host: resolve(:host), port: resolve(:port))
      #     end
      #   end
      #
      # @api private
      class Container
        # @!attribute [r] dependencies
        #   Stores registered dependency values
        #   @return [Hash{Symbol => Object}]
        protected attr_reader :dependencies

        # @!attribute [r] factories
        #   Stores factory blocks for computed dependencies
        #   @return [Hash{Symbol => Proc}]
        protected attr_reader :factories

        # @!attribute [r] initializers
        #   Stores optional transformation blocks for dependencies
        #   @return [Hash{Symbol => Proc}]
        protected attr_reader :initializers

        class << self
          # Define a container using a DSL block.
          #
          # This is a convenience method for creating and configuring a container
          # in a single expression.
          #
          # @yield Block evaluated in the context of the new container
          # @return [Stoplight::Infrastructure::DependencyInjection::Container] Configured container instance
          #
          # @example
          #   container = Container.define do
          #     register(:redis_url, "redis://localhost:6379")
          #     factory(:redis) { Redis.new(resolve(:redis_url)) }
          #   end
          def define(&definition)
            new.define(&definition)
          end
        end

        # Creates a new dependency injection container.
        #
        # @param dependencies [Hash{Symbol => Object}]
        # @param factories [Hash{Symbol => Proc}]
        # @param initializers [Hash{Symbol => Proc}]
        def initialize(dependencies: {}, factories: {}, initializers: {})
          @dependencies = dependencies
          @initializers = initializers
          @factories = factories
        end

        # Evaluate a configuration block in the context of this container.
        #
        # @yield Block evaluated in the context of the container
        # @return [Stoplight::Infrastructure::DependencyInjection::Container] self for method chaining
        #
        # @example
        #   container = Container.new
        #   container.define do
        #     register(:port, 8080)
        #     factory(:server) { Server.new(port: resolve(:port)) }
        #   end

        def define(&definition)
          instance_eval(&definition)
          freeze
          self
        end

        # Registers a dependency value with optional lazy initialization.
        #
        # The initializer block is called every time the dependency is resolved,
        # receiving the registered value as an argument. This allows for delayed
        # object construction or transformation of simple values into complex objects.
        #
        # @param name [Symbol] The dependency key
        # @param value [Object] The dependency value (may be transformed by initializer)
        # @yield [value] Optional transformation block
        # @yieldparam value [Object] The registered value
        # @yieldreturn [Object] The transformed value to return when resolving
        # @return [Stoplight::Infrastructure::DependencyInjection::Container] self for method chaining
        #
        # @example Register a simple dependency
        #   container.register(:port, 3000)
        #   container.resolve(:port) #=> 3000
        #
        # @example Register with lazy initialization
        #   container.register(:redis, "redis://localhost:6379") do |url|
        #     Redis.new(url)
        #   end
        #   container.resolve(:redis) #=> #<Redis...>
        #
        # @example Initialization is applied on every resolution
        #   container.register(:timestamp, Time.now, &:to_i)
        #   container.resolve(:timestamp) #=> 1234567890
        #
        #   # Update the value
        #   container.register(:timestamp, Time.now + 60)
        #   container.resolve(:timestamp) #=> 1234567950 (new timestamp)
        #
        def register(name, value, &initializer)
          dependencies[name] = value
          initializers[name] = initializer if block_given?
          self
        end

        # Resolves a dependency by name.
        #
        # Resolution order:
        # 1. Direct dependency with initializer (value is transformed)
        # 2. Direct dependency without initializer (value returned as-is)
        # 3. Factory (block evaluated in container context)
        # 4. Raises {Stoplight::Infrastructure::DependencyInjection::UnresolvedDependencyError}
        #
        # @param name [Symbol] The dependency key
        # @return [Object] The resolved dependency value
        # @raise [Stoplight::Infrastructure::DependencyInjection::UnresolvedDependencyError] if dependency is not registered
        #
        def resolve(name)
          if dependencies.key?(name)
            value = dependencies[name]
            if initializers.key?(name)
              initializer = initializers[name]
              instance_exec(value, &initializer)
            else
              value
            end
          elsif factories.key?(name)
            factory = factories[name]
            instance_eval(&factory)
          else
            raise UnresolvedDependencyError, name
          end
        end

        # Registers a factory for computing dependencies dynamically.
        #
        # Factories are evaluated lazily when the dependency is resolved.
        # The factory block is evaluated in the container's context, giving
        # it access to the +#resolve+ method for accessing other dependencies.
        #
        # Unlike +#register+ with an initializer, factories are not cached -
        # they are executed every time the dependency is resolved.
        #
        # @param key [Symbol] The dependency key
        # @yield Factory block evaluated in container context
        # @yieldreturn [Object] The computed dependency value
        # @return [Stoplight::Infrastructure::DependencyInjection::Container] self for method chaining
        #
        def factory(key, &factory)
          factories[key] = factory
          self
        end

        # Returns all registered dependency keys.
        #
        # This includes both direct dependencies and factory definitions.
        #
        # @return [Array<Symbol>] All registered dependency keys
        #
        # @example
        #   container.register(:port, 3000)
        #   container.factory(:server) { Server.new }
        #   container.keys #=> [:port, :server]
        #
        def keys
          factories.keys | dependencies.keys
        end

        # Creates a new container with merged dependencies.
        #
        # This is an immutable operation - the original container is not modified.
        # Factories and initializers are copied to the new container.
        #
        # @param new_dependencies [Hash{Symbol => Object}] Dependencies to merge/override
        # @return [Stoplight::Infrastructure::DependencyInjection::Container] New container with merged dependencies
        #
        # @example Creating specialized containers
        #   base = Container.define do
        #     register(:host, "localhost")
        #     register(:port, 3000)
        #   end
        #
        #   production = base.with(host: "prod.example.com", port: 80)
        #   staging = base.with(host: "staging.example.com", port: 8080)
        #
        #   base.resolve(:port) #=> 3000
        #   production.resolve(:port) #=> 80
        #   staging.resolve(:port) #=> 8080

        def with(**new_dependencies)
          self.class.new(
            dependencies: {**dependencies, **new_dependencies},
            factories:,
            initializers:
          )
        end

        def ==(other)
          other.is_a?(self.class) &&
            other.dependencies == dependencies &&
            other.factories == factories &&
            other.initializers == initializers
        end
      end
    end
  end
end
