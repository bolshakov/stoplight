# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::DependencyInjection::Container do
  describe ".define" do
    subject(:container) do
      described_class.define do
        register(:foo, 42)
      end
    end

    it "registers dependencies via the definition block" do
      expect(container.resolve(:foo)).to eq(42)
    end
  end

  describe "#register" do
    let(:container) { described_class.new }

    context "when registering a dependency without an initializer" do
      before do
        container.register(:foo, "bar")
      end

      it "can resolve the registered dependency" do
        expect(container.resolve(:foo)).to eq("bar")
      end

      context "when overriding dependency" do
        before do
          container.register(:foo, "baz")
        end

        it "resolves to the new value" do
          expect(container.resolve(:foo)).to eq("baz")
        end
      end
    end

    context "when registering a dependency with an initializer" do
      before do
        container.register(:foo, "bar", &:upcase)
      end

      it "can resolve the registered dependency with initializer applied" do
        expect(container.resolve(:foo)).to eq("BAR")
      end

      context "when overriding dependency" do
        before do
          container.register(:foo, "baz")
        end

        it "resolves to the new value with initializer applied" do
          expect(container.resolve(:foo)).to eq("BAZ")
        end
      end

      context "when overriding dependency and initializer" do
        before do
          container.register(:foo, "baz", &:length)
        end

        it "resolves to the new value with new initializer applied" do
          expect(container.resolve(:foo)).to eq(3)
        end
      end
    end
  end

  describe "#factory" do
    let(:container) { described_class.new }

    before do
      container.factory(:dynamic_value) do |c|
        "Value is #{c.resolve(:base_value)}"
      end
      container.register(:base_value, 100)
    end

    it "resolves the dependency using the factory" do
      expect(container.resolve(:dynamic_value)).to eq("Value is 100")
    end

    context "when dependency and factory with the same name registered" do
      before do
        container.register(:dynamic_value, "Static Value")
      end

      it "resolves to the registered dependency instead of factory" do
        expect(container.resolve(:dynamic_value)).to eq("Static Value")
      end
    end
  end

  describe "#keys" do
    let(:container) do
      described_class.define do
        register(:foo, 1)
        register(:bar, 2)
        factory(:baz) { 3 }
        factory(:bar) { 4 }
      end
    end

    it "returns all registered dependency and factory keys" do
      expect(container.keys).to contain_exactly(:foo, :bar, :baz)
    end
  end

  describe "#with" do
    let(:base_container) do
      described_class.define do
        register(:foo, "base_foo")
        register(:bar, "base_bar")
      end
    end

    let(:new_container) do
      base_container.with(foo: "new_foo", baz: "new_baz")
    end

    it "creates a new container with merged dependencies" do
      expect(new_container.resolve(:foo)).to eq("new_foo")
      expect(new_container.resolve(:bar)).to eq("base_bar")
      expect(new_container.resolve(:baz)).to eq("new_baz")
    end

    it "does not modify the original container" do
      expect(base_container.resolve(:foo)).to eq("base_foo")
      expect { base_container.resolve(:baz) }.to raise_error(Stoplight::Infrastructure::DependencyInjection::UnresolvedDependencyError)
    end
  end
end
