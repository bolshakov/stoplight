# frozen_string_literal: true

RSpec.shared_examples "Stoplight::DataStore::Base#transition_to_color" do
  let(:current_time) { Time.at(Time.now.to_i) }

  context "when transitioning to GREEN" do
    context "when the color is already GREEN" do
      before do
        data_store.transition_to_color(config, Stoplight::Color::GREEN)
      end

      it { expect(data_store.transition_to_color(config, Stoplight::Color::GREEN)).to be(false) }
    end

    context "when the color is YELLOW" do
      before do
        data_store.transition_to_color(config, Stoplight::Color::YELLOW)
      end

      it { expect(data_store.transition_to_color(config, Stoplight::Color::GREEN)).to be(true) }

      it "resets timestamps" do
        data_store.transition_to_color(config, Stoplight::Color::GREEN, current_time:)

        expect(data_store.get_metadata(config)).to have_attributes(
          recovery_started_at: nil,
          breached_at: nil,
          recovery_scheduled_after: nil
        )
      end
    end
  end

  context "when transitioning to YELLOW" do
    context "when the color is already YELLOW" do
      before do
        data_store.transition_to_color(config, Stoplight::Color::YELLOW)
      end

      it { expect(data_store.transition_to_color(config, Stoplight::Color::YELLOW)).to be(false) }
    end

    context "when the color is RED" do
      before do
        data_store.transition_to_color(config, Stoplight::Color::RED)
      end

      it { expect(data_store.transition_to_color(config, Stoplight::Color::YELLOW)).to be(true) }

      it "sets the recovery_started_at timestamp" do
        expect do
          data_store.transition_to_color(config, Stoplight::Color::YELLOW, current_time:)
        end.to change { data_store.get_metadata(config) }
          .from(have_attributes(recovery_started_at: nil))
          .to(have_attributes(recovery_started_at: current_time))
      end
    end
  end

  context "when transitioning to RED" do
    context "when the color is already RED" do
      before do
        data_store.transition_to_color(config, Stoplight::Color::RED)
      end

      it { expect(data_store.transition_to_color(config, Stoplight::Color::RED)).to be(false) }
    end

    context "when the color is YELLOW" do
      before do
        data_store.transition_to_color(config, Stoplight::Color::YELLOW)
      end

      it { expect(data_store.transition_to_color(config, Stoplight::Color::RED)).to be(true) }

      it "sets the breached_at and recovery_scheduled_after timestamps" do
        expect do
          data_store.transition_to_color(config, Stoplight::Color::RED, current_time:)
        end.to change { data_store.get_metadata(config) }
          .from(have_attributes(breached_at: nil, recovery_scheduled_after: nil))
          .to(have_attributes(breached_at: current_time, recovery_scheduled_after: current_time + config.cool_off_time))
      end
    end

    context "when the color is GREEN" do
      before do
        data_store.transition_to_color(config, Stoplight::Color::GREEN)
      end

      it { expect(data_store.transition_to_color(config, Stoplight::Color::RED)).to be(true) }

      it "sets the breached_at and recovery_scheduled_after timestamps" do
        expect do
          data_store.transition_to_color(config, Stoplight::Color::RED, current_time:)
        end.to change { data_store.get_metadata(config) }
          .from(have_attributes(breached_at: nil, recovery_scheduled_after: nil))
          .to(have_attributes(breached_at: current_time, recovery_scheduled_after: current_time + config.cool_off_time))
      end
    end

    context "when transitioning to an invalid color" do
      it "raises an ArgumentError" do
        expect {
          data_store.transition_to_color(config, "INVALID_COLOR")
        }.to raise_error(ArgumentError, "Invalid color: INVALID_COLOR")
      end
    end
  end
end
