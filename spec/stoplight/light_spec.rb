# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Stoplight::Light do
  let(:light) { Stoplight(name) }
  let(:name) { ('a'..'z').to_a.shuffle.join }

  it_behaves_like Stoplight::CircuitBreaker do
    let(:circuit_breaker) { described_class.new('foo', configuration) }
  end
end
