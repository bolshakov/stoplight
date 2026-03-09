# frozen_string_literal: true

RSpec.shared_examples "Stoplight::Domain::DataStore#transition_to_color" do
  let(:current_time) { Time.at(Time.now.to_i) }

  shared_examples "thread safe" do |color|
    let(:thread_count) { 50 }
    let(:barrier) { Concurrent::CyclicBarrier.new(thread_count) }
    let(:transition_results) { Concurrent::Array.new }

    it "returns true exactly once across concurrent calls" do
      threads = thread_count.times.map do
        Thread.new do
          barrier.wait  # All threads release simultaneously
          transition_results << transition_to_color(color)
        end
      end

      threads.each(&:join)

      expect(transition_results.count(true)).to eq(1)
      expect(transition_results.count(false)).to eq(thread_count - 1)
    end
  end

  context "when transitioning to GREEN" do
    context "when the color is already GREEN" do
      before do
        transition_to_color(Stoplight::Color::GREEN)
      end

      it { expect(transition_to_color(Stoplight::Color::GREEN)).to be(false) }
    end

    context "when the color is YELLOW" do
      before do
        transition_to_color(Stoplight::Color::YELLOW)
      end

      it { expect(transition_to_color(Stoplight::Color::GREEN)).to be(true) }

      it "resets timestamps" do
        Timecop.freeze(current_time) do
          transition_to_color(Stoplight::Color::GREEN)
        end

        expect(state_snapshot).to have_attributes(
          recovery_started_at: nil,
          breached_at: nil,
          recovery_scheduled_after: nil
        )
      end

      it_behaves_like "thread safe", Stoplight::Color::GREEN
    end
  end

  context "when transitioning to YELLOW" do
    context "when the color is already YELLOW" do
      before do
        transition_to_color(Stoplight::Color::YELLOW)
      end

      it { expect(transition_to_color(Stoplight::Color::YELLOW)).to be(false) }
    end

    context "when the color is RED" do
      before do
        transition_to_color(Stoplight::Color::RED)
      end

      it { expect(transition_to_color(Stoplight::Color::YELLOW)).to be(true) }

      it "sets the recovery_started_at timestamp" do
        expect do
          Timecop.freeze(current_time) do
            transition_to_color(Stoplight::Color::YELLOW)
          end
        end.to change { state_snapshot }
          .from(have_attributes(recovery_started_at: nil))
          .to(have_attributes(recovery_started_at: current_time))
      end

      context "when cleared" do
        it "looses persisted state" do
          Timecop.freeze(current_time) do
            transition_to_color(Stoplight::Color::YELLOW)
          end
          clear
          expect(state_snapshot).to have_attributes(recovery_started_at: nil)
        end
      end

      it_behaves_like "thread safe", Stoplight::Color::YELLOW
    end
  end

  context "when transitioning to RED" do
    context "when the color is already RED" do
      before do
        transition_to_color(Stoplight::Color::RED)
      end

      it { expect(transition_to_color(Stoplight::Color::RED)).to be(false) }
    end

    context "when the color is YELLOW" do
      before do
        transition_to_color(Stoplight::Color::YELLOW)
      end

      it { expect(transition_to_color(Stoplight::Color::RED)).to be(true) }

      it "sets the breached_at and recovery_scheduled_after timestamps" do
        expect do
          Timecop.freeze(current_time) do
            transition_to_color(Stoplight::Color::RED)
          end
        end.to change { state_snapshot }
          .from(have_attributes(breached_at: nil, recovery_scheduled_after: nil))
          .to(have_attributes(breached_at: current_time, recovery_scheduled_after: current_time + cool_off_time))
      end

      context "when cleared" do
        it "looses persisted state" do
          Timecop.freeze(current_time) do
            transition_to_color(Stoplight::Color::YELLOW)
          end
          clear
          expect(state_snapshot).to have_attributes(breached_at: nil, recovery_scheduled_after: nil)
        end
      end

      it_behaves_like "thread safe", Stoplight::Color::RED
    end

    context "when the color is GREEN" do
      before do
        transition_to_color(Stoplight::Color::GREEN)
      end

      it { expect(transition_to_color(Stoplight::Color::RED)).to be(true) }

      it "sets the breached_at and recovery_scheduled_after timestamps" do
        expect do
          Timecop.freeze(current_time) do
            transition_to_color(Stoplight::Color::RED)
          end
        end.to change { state_snapshot }
          .from(have_attributes(breached_at: nil, recovery_scheduled_after: nil))
          .to(have_attributes(breached_at: current_time, recovery_scheduled_after: current_time + cool_off_time))
      end

      context "when cleared" do
        it "looses persisted state" do
          Timecop.freeze(current_time) do
            transition_to_color(Stoplight::Color::YELLOW)
          end
          clear
          expect(state_snapshot).to have_attributes(breached_at: nil, recovery_scheduled_after: nil)
        end
      end

      it_behaves_like "thread safe", Stoplight::Color::RED
    end

    context "when transitioning to an invalid color" do
      it "raises an ArgumentError" do
        expect {
          transition_to_color("INVALID_COLOR")
        }.to raise_error(ArgumentError, "Invalid color: INVALID_COLOR")
      end
    end
  end
end
