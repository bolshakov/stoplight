# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Stoplight::CircuitBreaker do
  subject(:circuit_breaker) { klass.new }

  let(:klass) do
    Class.new { include Stoplight::CircuitBreaker }
  end

  specify '#with_error_handler' do
    expect { circuit_breaker.with_error_handler {} }.to raise_error(NotImplementedError)
  end

  specify '#with_fallback' do
    expect { circuit_breaker.with_fallback {} }.to raise_error(NotImplementedError)
  end

  specify '#color' do
    expect { circuit_breaker.color }.to raise_error(NotImplementedError)
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
