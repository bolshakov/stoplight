# frozen_string_literal: true

require "pg"

RSpec.describe Stoplight::DataStore::Postgres do
  let(:connection) { instance_double(PG::Connection) }

  it "exposes the connection" do
    expect(described_class.new(connection).connection).to be(connection)
  end

  it "defaults warn_on_clock_skew to true" do
    expect(described_class.new(connection).warn_on_clock_skew).to be(true)
  end

  it "accepts warn_on_clock_skew: false" do
    expect(described_class.new(connection, warn_on_clock_skew: false).warn_on_clock_skew).to be(false)
  end

  it "is a DataStore::Base" do
    expect(described_class.new(connection)).to be_a(Stoplight::DataStore::Base)
  end
end
