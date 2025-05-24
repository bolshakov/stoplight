# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stoplight::TrafficControl::Base do
  let(:strategy) { described_class.new }

  describe "#stop_traffic?" do
    it "raises NotImplementedError when called without implementation" do
      expect { strategy.stop_traffic?(nil, nil) }.to raise_error(NotImplementedError)
    end
  end
end
