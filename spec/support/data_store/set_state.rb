# frozen_string_literal: true

RSpec.shared_examples "Stoplight::Domain::DataStore#set_state" do
  let(:state) { "state" }

  it "returns the state" do
    expect(set_state(state)).to eql(state)
  end

  it "persists the state" do
    set_state(state)

    expect(get_state_snapshot.locked_state).to eql(state)
  end
end
