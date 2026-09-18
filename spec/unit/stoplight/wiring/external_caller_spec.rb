# frozen_string_literal: true

RSpec.describe Stoplight::Wiring::ExternalCaller do
  describe ".backtrace" do
    it "starts at the calling line" do
      line = __LINE__ + 1
      backtrace = described_class.backtrace

      expect(backtrace.first).to include("#{__FILE__}:#{line}")
    end

    it "drops Stoplight's own frames" do
      inside_lib = "#{described_class::LIB_ROOT}wiring/anything.rb"
      backtrace = Object.new.instance_eval("Stoplight::Wiring::ExternalCaller.backtrace", inside_lib, 1) # rubocop:disable Style/EvalWithLocation

      expect(backtrace).not_to include(a_string_including(inside_lib))
    end

    it "drops Ruby core frames" do
      backtrace = 1.then { described_class.backtrace }

      expect(backtrace).not_to include(a_string_including("<internal:"))
    end
  end
end
