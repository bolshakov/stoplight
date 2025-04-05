# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Stoplight::CircuitBreaker do
  subject(:circuit_breaker) { klass.new }

  let(:klass) do
    Class.new { include Stoplight::CircuitBreaker }
  end

  specify '#color' do
    expect { circuit_breaker.color }.to raise_error(NotImplementedError)
  end

  specify '#state' do
    expect { circuit_breaker.state }.to raise_error(NotImplementedError)
  end

  specify '#name' do
    expect { circuit_breaker.name }.to raise_error(NotImplementedError)
  end

  specify '#run' do
    expect { circuit_breaker.run {} }.to raise_error(NotImplementedError)
  end

  specify '#lock' do
    expect { circuit_breaker.lock('red') }.to raise_error(NotImplementedError)
  end

  specify '#unlock' do
    expect { circuit_breaker.unlock }.to raise_error(NotImplementedError)
  end
end
