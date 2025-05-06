# frozen_string_literal: true

RSpec.shared_examples "Stoplight::Light::Runnable#run" do
  subject(:light) { Stoplight::Light.new(config, green_run_strategy:, yellow_run_strategy:, red_run_strategy:) }

  let(:green_run_strategy) { instance_double(Stoplight::Light::RunStrategy) }
  let(:yellow_run_strategy) { instance_double(Stoplight::Light::RunStrategy) }
  let(:red_run_strategy) { instance_double(Stoplight::Light::RunStrategy) }
  let(:code) { -> { code_result } }
  let(:code_result) { random_string }
  let(:fallback) { instance_double(Proc) }
  let(:name) { random_string }

  def run(fallback = nil)
    light.run(fallback, &code)
  end

  context "when the light is green" do
    before do
      data_store.transition_to_color(config, Stoplight::Color::GREEN)
    end

    it "executes green strategy" do
      expect do |block|
        expect(green_run_strategy).to receive(:execute) do |fb, &code|
          expect(fb).to eq(fallback)
          code.call
          42
        end

        expect(light.run(fallback, &block)).to eq(42)
      end.to yield_control
    end
  end

  context "when the light is red" do
    before do
      data_store.transition_to_color(config, Stoplight::Color::RED)
    end

    it "executes red strategy" do
      expect do |block|
        expect(red_run_strategy).to receive(:execute) do |fb, &code|
          expect(fb).to eq(fallback)
          code.call
          43
        end

        expect(light.run(fallback, &block)).to eq(43)
      end.to yield_control
    end
  end

  context "when the light is yellow" do
    before do
      data_store.transition_to_color(config, Stoplight::Color::YELLOW)
    end

    it "executes yellow strategy" do
      expect do |block|
        expect(yellow_run_strategy).to receive(:execute) do |fb, &code|
          expect(fb).to eq(fallback)
          code.call
          44
        end

        expect(light.run(fallback, &block)).to eq(44)
      end.to yield_control
    end
  end
end
