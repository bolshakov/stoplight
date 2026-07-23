# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Failure do
  let(:error) { ZeroDivisionError.new("divided by 0") }
  let(:error_class) { error.class.name }
  let(:error_message) { error.message }
  let(:time) { Time.new(2001, 2, 3, 4, 5, 6, "+07:08") }
  let(:json) do
    JSON.generate(
      error: {class: error_class, message: error_message},
      time: time.to_i
    )
  end

  it "is a class" do
    expect(described_class).to be_a(Class)
  end

  describe ".from_error" do
    it "creates a failure" do
      Timecop.freeze do
        failure = described_class.from_error(error, time: Time.now)
        expect(failure.error_class).to eql(error_class)
        expect(failure.error_message).to eql(error_message)
        expect(failure.time.to_i).to eql(Time.new.to_i)
      end
    end
  end

  describe "#==" do
    it "is true when they are equal" do
      failure = described_class.new(error_class, error_message, time)
      other = described_class.new(error_class, error_message, time)
      expect(failure).to eq(other)
    end

    it "is false when they have different error classes" do
      failure = described_class.new(error_class, error_message, time)
      other = described_class.new(nil, error_message, time)
      expect(failure).to_not eq(other)
    end

    it "is false when they have different error messages" do
      failure = described_class.new(error_class, error_message, time)
      other = described_class.new(error_class, nil, time)
      expect(failure).to_not eq(other)
    end

    it "is false when they have different times" do
      failure = described_class.new(error_class, error_message, time)
      other = described_class.new(error_class, error_message, nil)
      expect(failure).to_not eq(other)
    end
  end

  describe "#error_class" do
    it "reads the error class" do
      expect(described_class.new(error_class, nil, nil).error_class)
        .to eql(error_class)
    end
  end

  describe "#error_message" do
    it "reads the error message" do
      expect(described_class.new(nil, error_message, nil).error_message)
        .to eql(error_message)
    end
  end

  describe "#time" do
    it "reads the time" do
      expect(described_class.new(nil, nil, time).time).to eql(time)
    end
  end

  describe "#==" do
    context "when the objects are equal" do
      let(:other) { described_class.new(error_class, error_message, time) }

      it "returns true" do
        expect(described_class.new(error_class, error_message, time)).to eq(other)
      end
    end

    context "when the objects are not equal" do
      let(:other) { described_class.new(error_class, "msg", time) }

      it "returns false" do
        expect(described_class.new(error_class, error_message, time)).not_to eq(other)
      end
    end
  end

  describe "#eql? and #hash" do
    let(:failure) { described_class.new(error_class, error_message, time) }
    let(:other) { described_class.new(error_class, error_message, time) }

    it "is eql when equal" do
      expect(failure).to eql(other)
    end

    it "has the same hash when equal" do
      expect(failure.hash).to eq(other.hash)
    end

    it "collides as hash keys when equal" do
      expect({failure => 1, other => 2}.size).to eq(1)
    end

    it "dedupes in an array when equal" do
      expect([failure, other].uniq.size).to eq(1)
    end
  end
end
