# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe Stoplight::Light::Runnable, :redis do
  subject(:light) { Stoplight::Light.new(name, &code) }

  let(:code) { -> { code_result } }
  let(:code_result) { random_string }
  let(:fallback) { ->(_) { fallback_result } }
  let(:fallback_result) { random_string }
  let(:name) { random_string }

  let(:failure) do
    Stoplight::Failure.new(error.class.name, error.message, time)
  end
  let(:error) { error_class.new(error_message) }
  let(:error_class) { Class.new(StandardError) }
  let(:error_message) { random_string }
  let(:time) { Time.new }

  def random_string
    ('a'..'z').to_a.sample(8).join
  end

  before do
    light.with_data_store(data_store)
  end

  context 'with memory data store' do
    let(:data_store) { Stoplight::DataStore::Memory.new }

    it_behaves_like 'Stoplight::Light::Runnable#color'
    it_behaves_like 'Stoplight::Light::Runnable#run'
  end

  context 'with redis data store', :redis do
    let(:data_store) { Stoplight::DataStore::Redis.new(redis) }

    it_behaves_like 'Stoplight::Light::Runnable#color'
    it_behaves_like 'Stoplight::Light::Runnable#run'
  end
end
