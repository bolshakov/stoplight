# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::Memory::Storage::State do
  subject(:storage) { described_class.new(clock:, cool_off_time:) }

  let(:clock) { Stoplight::Infrastructure::SystemClock.new }
  let(:cool_off_time) { 60 }

  def state_snapshot = storage.state_snapshot
  def clear = storage.clear

  it_behaves_like "Stoplight::Domain::DataStore#set_state" do
    def set_state(state) = storage.set_state(state)
  end

  it_behaves_like "Stoplight::Domain::DataStore#transition_to_color" do
    def transition_to_color(color) = storage.transition_to_color(color)
  end
end
