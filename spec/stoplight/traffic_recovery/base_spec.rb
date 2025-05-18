# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stoplight::TrafficRecovery::Base do
  let(:strategy) { described_class.new }

  describe "#determine_color" do
    it "raises NotImplementedError when called without implementation" do
      expect { strategy.determine_color(nil, nil) }.to raise_error(NotImplementedError)
    end
  end
end
