# frozen_string_literal: true

RSpec.describe Stoplight::Admin::Actions::Action do
  subject(:call) { described_class.new(lights_repository: lights_repository).call(params) }

  let(:params) { [] }
  let(:lights_repository) { instance_double(Stoplight::Admin::LightsRepository) }

  it "raises NonImplementedError" do
    expect { call }.to raise_error NotImplementedError
  end
end
