# frozen_string_literal: true

RSpec.describe Stoplight::Wiring::DefaultConfiguration do
  let(:default_config) { described_class.new }

  context "without any settings" do
    it "contains only default notifiers" do
      expect(default_config.notifiers).to eq(Stoplight::Wiring::Default::NOTIFIERS)
    end
  end
end
