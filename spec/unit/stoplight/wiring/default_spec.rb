# frozen_string_literal: true

RSpec.describe Stoplight::Wiring::Default do
  it "is a module" do
    expect(described_class).to be_a(Module)
  end

  describe "::COOL_OFF_TIME" do
    it "is a float" do
      expect(described_class::COOL_OFF_TIME).to be_a(Float)
    end
  end

  describe "::DATA_STORE" do
    it "is a data store" do
      expect(described_class::DATA_STORE).to be_a(Stoplight::DataStore::Memory)
    end
  end

  describe "::ERROR_NOTIFIER" do
    it "is a proc" do
      expect(described_class::ERROR_NOTIFIER).to be_a(Proc)
    end

    it "has an arity of 1" do
      expect(described_class::ERROR_NOTIFIER.arity).to eql(1)
    end
  end

  describe "::FORMATTER" do
    it "is a proc" do
      expect(described_class::FORMATTER).to be_a(Proc)
    end

    it "has the same arity as #notify" do
      notify = Stoplight::Domain::StateTransitionNotifier.new.method(:notify)
      expect(described_class::FORMATTER.arity).to eql(notify.arity)
    end
  end

  describe "::NOTIFIERS" do
    it "is an array" do
      expect(described_class::NOTIFIERS).to be_an(Array)
    end

    it "contains notifiers" do
      described_class::NOTIFIERS.each do |notifier|
        expect(notifier).to be_a(Stoplight::Domain::StateTransitionNotifier)
      end
    end

    it "is frozen" do
      expect(described_class::NOTIFIERS).to be_frozen
    end
  end

  describe "::THRESHOLD" do
    it "is an integer" do
      expect(described_class::THRESHOLD).to be_a(Integer)
    end
  end
end
