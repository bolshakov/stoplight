# frozen_string_literal: true

RSpec.describe "Configuration error locations" do
  before do
    Stoplight.configure(trust_me_im_an_engineer: true) do |config|
      config.data_store = Stoplight::DataStore::Memory.new
    end
  end

  def register_deeply(depth, name, **settings)
    return Stoplight(name, **settings) if depth.zero?

    register_deeply(depth - 1, name, **settings)
  end

  it "blames the line that registered a light with an invalid window_size" do
    line = __LINE__ + 2
    expect {
      Stoplight(SecureRandom.uuid, window_size: 0.5)
    }.to raise_error(Stoplight::Error::ConfigurationError) { |error|
      expect(error.backtrace.first).to include("#{__FILE__}:#{line}")
    }
  end

  it "names the original registration site in the message" do
    name = SecureRandom.uuid

    original_line = __LINE__ + 1
    Stoplight(name, threshold: 5)

    expect {
      Stoplight(name, threshold: 10)
    }.to raise_error(
      Stoplight::Error::ConfigurationError,
      include("#{__FILE__}:#{original_line}")
    )
  end

  it "points the error's own backtrace at the conflicting call site" do
    name = SecureRandom.uuid
    Stoplight(name, threshold: 5)

    conflicting_line = __LINE__ + 2
    expect {
      Stoplight(name, threshold: 10)
    }.to raise_error(Stoplight::Error::ConfigurationError) { |error|
      expect(error.backtrace.first).to include("#{__FILE__}:#{conflicting_line}")
    }
  end

  it "names the nested registration site before the enclosing light's, with no Stoplight frames" do
    outer = SecureRandom.uuid
    name = SecureRandom.uuid

    outer_line = __LINE__ + 1
    Stoplight(outer).run do
      Stoplight(name, threshold: 5)
    end
    inner_line = outer_line + 1

    expect {
      Stoplight(outer).run { Stoplight(name, threshold: 10) }
    }.to raise_error(Stoplight::Error::ConfigurationError) { |error|
      frames = error.message.lines.grep(/^  /).map(&:strip)

      expect(frames[0]).to include("#{__FILE__}:#{inner_line}")
      expect(frames[1]).to include("#{__FILE__}:#{outer_line}")
      expect(frames).not_to include(a_string_matching(%r{lib/stoplight/}))
    }
  end

  it "shows how the original registration was reached, not just its line" do
    name = SecureRandom.uuid

    calling_line = __LINE__ + 1
    register_deeply(2, name, threshold: 5)

    expect {
      Stoplight(name, threshold: 10)
    }.to raise_error(
      Stoplight::Error::ConfigurationError,
      include("#{__FILE__}:#{calling_line}").and(include("register_deeply"))
    )
  end

  it "points an incompatible-configuration error at the caller" do
    incompatible_line = __LINE__ + 3

    expect {
      Stoplight(
        SecureRandom.uuid,
        traffic_control: Stoplight::Domain::TrafficControl::ErrorRate.new,
        threshold: 5,
        window_size: 20
      )
    }.to raise_error(Stoplight::Error::ConfigurationError) { |error|
      expect(error.backtrace.first).to include("#{__FILE__}:#{incompatible_line}")
    }
  end

  it "keeps the full stack on the error itself" do
    name = SecureRandom.uuid
    Stoplight(name, threshold: 5)

    expect {
      register_deeply(10, name, threshold: 10)
    }.to raise_error(Stoplight::Error::ConfigurationError) { |error|
      expect(error.backtrace.grep(/register_deeply/).size).to eq(11)
    }
  end

  it "caps the stored registration stack so deep stacks stay readable" do
    name = SecureRandom.uuid
    register_deeply(40, name, threshold: 5)

    expect {
      Stoplight(name, threshold: 10)
    }.to raise_error(Stoplight::Error::ConfigurationError) { |error|
      frames = error.message.lines.grep(/#{Regexp.escape(__FILE__)}/)
      expect(frames.size).to eq(5)
    }
  end
end
