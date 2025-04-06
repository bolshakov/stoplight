# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Stoplight::CircuitBreaker do
  subject(:circuit_breaker) { klass.new }

  let(:klass) do
    Class.new { include Stoplight::CircuitBreaker }
  end

  specify '#state' do
    expect { circuit_breaker.state }.to raise_error(NotImplementedError)
  end

  specify '#name' do
    expect { circuit_breaker.name }.to raise_error(NotImplementedError)
  end
end
