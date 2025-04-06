# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe Stoplight::Light::Runnable, :redis do
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

  let(:light) { Stoplight(name).with_data_store(data_store) }

  context 'with memory data store' do
    let(:data_store) { Stoplight::DataStore::Memory.new }

    it_behaves_like 'Stoplight::Light::Runnable#state'
    it_behaves_like 'Stoplight::Light::Runnable#color'
    it_behaves_like 'Stoplight::Light::Runnable#run'
  end

  context 'with redis data store', :redis do
    let(:data_store) { Stoplight::DataStore::Redis.new(redis) }

    it_behaves_like 'Stoplight::Light::Runnable#state'
    it_behaves_like 'Stoplight::Light::Runnable#color'
    it_behaves_like 'Stoplight::Light::Runnable#run'
  end
end
