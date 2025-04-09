# frozen_string_literal: true

require_relative 'base/names'
require_relative 'base/get_failures'
require_relative 'base/get_all'
require_relative 'base/record_failures'
require_relative 'base/clear_failures'
require_relative 'base/get_state'
require_relative 'base/set_state'
require_relative 'base/clear_state'
require_relative 'base/with_deduplicated_notification'

RSpec.shared_examples 'Stoplight::DataStore::Base' do
  it 'is a class' do
    expect(described_class).to be_a(Class)
  end

  it 'is a subclass of Base' do
    expect(described_class).to be < Stoplight::DataStore::Base
  end
end
