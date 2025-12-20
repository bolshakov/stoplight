# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::SystemClock do
  subject(:clock) { described_class.new }

  describe "#current_time" do
    subject(:current_time) { clock.current_time }

    around do |example|
      Timecop.freeze { example.run }
    end

    it "returns current wall-clock time" do
      expect(current_time).to eq(Time.now)
    end
  end

  describe "#at" do
    subject(:at) { clock.at(timestamp) }

    context "with integer timestamp" do
      let(:timestamp) { 1705329000 }

      it "converts to Time" do
        expect(at).to eq(Time.at(timestamp))
      end
    end

    context "with float timestamp (sub-second precision)" do
      let(:timestamp) { 1705329000.123456 }

      it "preserves sub-second precision" do
        expect(at.nsec).to be > 0
      end
    end

    context "with zero timestamp (Unix epoch)" do
      let(:timestamp) { 0 }

      it "returns epoch time" do
        expect(at.utc).to eq(Time.utc(1970, 1, 1))
      end
    end
  end
end
