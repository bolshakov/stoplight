# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stoplight::DataStore::Base do
  let(:data_store) { described_class.new }

  it "is a class" do
    expect(described_class).to be_a(Class)
  end

  describe "#names" do
    it "is not implemented" do
      expect { data_store.names }.to raise_error(NotImplementedError)
    end
  end

  describe "#record_failure" do
    it "is not implemented" do
      expect { data_store.record_failure(nil, nil) }
        .to raise_error(NotImplementedError)
    end
  end

  describe "#record_success" do
    it "is not implemented" do
      expect { data_store.record_success(nil) }
        .to raise_error(NotImplementedError)
    end
  end

  describe "#record_recovery_probe_failure" do
    it "is not implemented" do
      expect { data_store.record_recovery_probe_failure(nil, nil) }
        .to raise_error(NotImplementedError)
    end
  end

  describe "#record_recovery_probe_success" do
    it "is not implemented" do
      expect { data_store.record_recovery_probe_success(nil) }
        .to raise_error(NotImplementedError)
    end
  end

  describe "#set_state" do
    it "is not implemented" do
      expect { data_store.set_state(nil, nil) }
        .to raise_error(NotImplementedError)
    end
  end

  describe "#clear_state" do
    it "is not implemented" do
      expect { data_store.clear_state(nil) }
        .to raise_error(NotImplementedError)
    end
  end

  describe "#transition_to_color" do
    it "is not implemented" do
      expect { data_store.transition_to_color(nil, nil) }
        .to raise_error(NotImplementedError)
    end
  end

  describe "#get_metadata" do
    it "is not implemented" do
      expect { data_store.get_metadata(nil) }
        .to raise_error(NotImplementedError)
    end
  end
end
