# frozen_string_literal: true

RSpec.shared_examples "Stoplight::Light::Runnable#color" do
  let(:name) { random_string }

  it "is initially GREEN" do
    expect(light.color).to eql(Stoplight::Color::GREEN)
  end

  context "when its locked GREEN" do
    before do
      data_store.set_state(config, Stoplight::State::LOCKED_GREEN)
    end

    it "is GREEN" do
      expect(light.color).to eql(Stoplight::Color::GREEN)
    end
  end

  context "when its locked RED" do
    before do
      data_store.set_state(config, Stoplight::State::LOCKED_RED)
    end

    it "is RED" do
      expect(light.color).to eql(Stoplight::Color::RED)
    end
  end

  context "when transitioned to RED" do
    before do
      data_store.transition_to_color(config, Stoplight::Color::RED)
    end

    it "is RED" do
      expect(light.color).to eql(Stoplight::Color::RED)
    end
  end

  context "when transitioned to YELLOW" do
    before do
      data_store.transition_to_color(config, Stoplight::Color::YELLOW)
    end

    it "is YELLOW" do
      expect(light.color).to eql(Stoplight::Color::YELLOW)
    end
  end
end
