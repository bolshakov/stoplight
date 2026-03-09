# frozen_string_literal: true

require "rubocop"
require "rubocop/rspec/support"
require_relative "../../../rubocop/stoplight/architecture_boundaries"

RSpec.describe RuboCop::Cop::Stoplight::ArchitectureBoundaries, :config do
  let(:config) { RuboCop::Config.new }

  context "when in domain layer" do
    let(:filename) { "lib/stoplight/domain/light.rb" }

    it "detects absolute Infrastructure reference" do
      expect_offense(<<~RUBY, filename)
        module Stoplight
          module Domain
            class Light
              def foo
                Stoplight::Infrastructure::DataStore.new
                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Stoplight/ArchitectureBoundaries: domain cannot depend on infrastructure
              end
            end
          end
        end
      RUBY
    end

    it "detects relative Infrastructure reference" do
      expect_offense(<<~RUBY, filename)
        module Stoplight
          module Domain
            class Light
              def foo
                Infrastructure::DataStore.new
                ^^^^^^^^^^^^^^^^^^^^^^^^^ Stoplight/ArchitectureBoundaries: domain cannot depend on infrastructure
              end
            end
          end
        end
      RUBY
    end

    it "detects short-form Infrastructure reference" do
      expect_offense(<<~RUBY, filename)
        module Stoplight::Domain
          class Light
            def foo
              Infrastructure::DataStore.new
              ^^^^^^^^^^^^^^^^^^^^^^^^^ Stoplight/ArchitectureBoundaries: domain cannot depend on infrastructure
            end
          end
        end
      RUBY
    end

    it "detects Infrastructure in include statement" do
      expect_offense(<<~RUBY, filename)
        module Stoplight
          module Domain
            class Light
              include Infrastructure::Helpers
                      ^^^^^^^^^^^^^^^^^^^^^^^ Stoplight/ArchitectureBoundaries: domain cannot depend on infrastructure
            end
          end
        end
      RUBY
    end

    it "detects Wiring reference" do
      expect_offense(<<~RUBY, filename)
        module Stoplight
          module Domain
            class Light
              def foo
                Wiring::Container.new
                ^^^^^^^^^^^^^^^^^ Stoplight/ArchitectureBoundaries: domain cannot depend on wiring
              end
            end
          end
        end
      RUBY
    end

    it "allows references within domain" do
      expect_no_offenses(<<~RUBY, filename)
        module Stoplight
          module Domain
            class Light
              def foo
                Color.new
                Stoplight::Domain::State.new
              end
            end
          end
        end
      RUBY
    end
  end

  context "when in infrastructure layer" do
    let(:filename) { "lib/stoplight/infrastructure/data_store/redis.rb" }

    it "allows Domain references" do
      expect_no_offenses(<<~RUBY, filename)
        module Stoplight
          module Infrastructure
            class Redis
              def foo
                Domain::Light.new
                Stoplight::Color.new
              end
            end
          end
        end
      RUBY
    end

    it "detects Wiring reference" do
      expect_offense(<<~RUBY, filename)
        module Stoplight
          module Infrastructure
            class Redis
              def foo
                Wiring::Container.resolve(:foo)
                ^^^^^^^^^^^^^^^^^ Stoplight/ArchitectureBoundaries: infrastructure cannot depend on wiring
              end
            end
          end
        end
      RUBY
    end

    it "detects Admin reference" do
      expect_offense(<<~RUBY, filename)
        module Stoplight::Infrastructure
          class Redis
            def foo
              Admin::LightsRepository.new
              ^^^^^^^^^^^^^^^^^^^^^^^ Stoplight/ArchitectureBoundaries: infrastructure cannot depend on admin
            end
          end
        end
      RUBY
    end
  end

  context "when in wiring layer" do
    let(:filename) { "lib/stoplight/wiring/container.rb" }

    it "allows Domain and Infrastructure references" do
      expect_no_offenses(<<~RUBY, filename)
        module Stoplight
          module Wiring
            class Container
              def foo
                Domain::Light.new
                Infrastructure::Redis::DataStore.new
              end
            end
          end
        end
      RUBY
    end

    it "detects Admin reference" do
      expect_offense(<<~RUBY, filename)
        module Stoplight
          module Wiring
            class Container
              def foo
                Admin::Helpers.some_method
                ^^^^^^^^^^^^^^ Stoplight/ArchitectureBoundaries: wiring cannot depend on admin
              end
            end
          end
        end
      RUBY
    end
  end

  context "when in admin layer" do
    let(:filename) { "lib/stoplight/admin/lights_repository.rb" }

    it "allows references to all layers" do
      expect_no_offenses(<<~RUBY, filename)
        module Stoplight
          module Admin
            class LightsRepository
              def foo
                Domain::Light.new
                Infrastructure::Redis::DataStore.new
                Wiring::Container.resolve(:foo)
              end
            end
          end
        end
      RUBY
    end
  end

  context "with edge cases" do
    let(:filename) { "lib/stoplight/domain/light.rb" }

    it "handles constant assignment" do
      expect_offense(<<~RUBY, filename)
        module Stoplight::Domain
          class Light
            DataStore = Infrastructure::DataStore
                        ^^^^^^^^^^^^^^^^^^^^^^^^^ Stoplight/ArchitectureBoundaries: domain cannot depend on infrastructure
          end
        end
      RUBY
    end

    it "handles nested constant references" do
      expect_offense(<<~RUBY, filename)
        module Stoplight
          module Domain
            class Light
              def foo
                Infrastructure::Redis::DataStore::Connection.new
                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Stoplight/ArchitectureBoundaries: domain cannot depend on infrastructure
              end
            end
          end
        end
      RUBY
    end

    it "ignores non-Stoplight constants" do
      expect_no_offenses(<<~RUBY, filename)
        module Stoplight
          module Domain
            class Light
              def foo
                Redis::Connection.new
                StandardError.new
                MyApp::Domain::Something.new
              end
            end
          end
        end
      RUBY
    end
  end

  context "when domain references composition root" do
    let(:filename) { "lib/stoplight/domain/circuit_manager.rb" }

    it "detects Stoplight.light() call" do
      expect_offense(<<~RUBY, filename)
        module Stoplight::Domain
          class CircuitManager
            def create
              Stoplight.light("test")
              ^^^^^^^^^^^^^^^^^^^^^^^ Stoplight/ArchitectureBoundaries: domain cannot reference Stoplight composition root (use Domain::Light directly)
            end
          end
        end
      RUBY
    end

    it "detects Stoplight.configure() call" do
      expect_offense(<<~RUBY, filename)
        module Stoplight::Domain
          class CircuitManager
            def setup
              Stoplight.configure do |config|
              ^^^^^^^^^^^^^^^^^^^ Stoplight/ArchitectureBoundaries: domain cannot reference Stoplight composition root (use Domain::Light directly)
                # ...
              end
            end
          end
        end
      RUBY
    end

    it "detects Stoplight::DataStore::Memory reference" do
      expect_offense(<<~RUBY, filename)
        module Stoplight::Domain
          class CircuitManager
            def create_store
              Stoplight::DataStore::Memory.new
              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Stoplight/ArchitectureBoundaries: domain cannot reference Stoplight composition root (use Domain::Light directly)
            end
          end
        end
      RUBY
    end

    it "allows Domain::Light" do
      expect_no_offenses(<<~RUBY, filename)
        module Stoplight::Domain
          class CircuitManager
            def create
              Domain::Light.new(name: "test")
            end
          end
        end
      RUBY
    end

    it "allows Stoplight::Domain::Light (explicit full path)" do
      expect_no_offenses(<<~RUBY, filename)
        module Stoplight::Domain
          class CircuitManager
            def create
              Stoplight::Domain::Light.new(name: "test")
            end
          end
        end
      RUBY
    end
  end

  context "when in domain spec files" do
    let(:filename) { "spec/unit/stoplight/domain/light_spec.rb" }

    it "detects Infrastructure in instance_double" do
      expect_offense(<<~RUBY, filename)
        RSpec.describe Stoplight::Domain::Light do
          it "uses infrastructure" do
            store = instance_double(Infrastructure::Redis::DataStore)
                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Stoplight/ArchitectureBoundaries: domain cannot depend on infrastructure (use domain interface in test doubles instead)
          end
        end
      RUBY
    end

    it "detects Infrastructure in class_double" do
      expect_offense(<<~RUBY, filename)
        RSpec.describe Stoplight::Domain::Light do
          it "uses infrastructure" do
            store = class_double(Infrastructure::DataStore)
                                 ^^^^^^^^^^^^^^^^^^^^^^^^^ Stoplight/ArchitectureBoundaries: domain cannot depend on infrastructure (use domain interface in test doubles instead)
          end
        end
      RUBY
    end

    it "allows Domain interface in instance_double" do
      expect_no_offenses(<<~RUBY, filename)
        RSpec.describe Stoplight::Domain::Light do
          it "uses domain interface" do
            store = instance_double(Stoplight::Domain::_DataStore)
          end
        end
      RUBY
    end

    it "allows Infrastructure in describe block" do
      expect_no_offenses(<<~RUBY, filename)
        RSpec.describe Infrastructure::Redis::DataStore do
          # This is fine - we're describing what we're testing
        end
      RUBY
    end

    it "allows Infrastructure in context description" do
      expect_no_offenses(<<~RUBY, filename)
        RSpec.describe Stoplight::Domain::Light do
          context "when using Infrastructure::DataStore" do
            # This is fine - it's just a description
          end
        end
      RUBY
    end

    it "allows Infrastructure in stub_const string" do
      expect_no_offenses(<<~RUBY, filename)
        RSpec.describe Stoplight::Domain::Light do
          before do
            stub_const("Infrastructure::DataStore", double)
          end
        end
      RUBY
    end

    it "disallows Infrastructure in allow/expect receiver" do
      expect_offense(<<~RUBY, filename)
        RSpec.describe Stoplight::Domain::Light do
          it "stubs" do
            allow(Infrastructure::DataStore).to receive(:new)
                  ^^^^^^^^^^^^^^^^^^^^^^^^^ Stoplight/ArchitectureBoundaries: domain cannot depend on infrastructure (use domain interface in test doubles instead)
          end
        end
      RUBY
    end
  end
end
