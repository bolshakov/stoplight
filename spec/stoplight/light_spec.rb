# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Stoplight::Light do
  let(:name) { ('a'..'z').to_a.shuffle.join }

  it_behaves_like Stoplight::Light::Configurable do
    let(:light) { described_class.new(config) }
  end
end
