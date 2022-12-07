# frozen_string_literal: true

RSpec.shared_examples Stoplight::Strategy::Vintage do
  subject(:strategy) { described_class.new(data_store) }
  let(:light) { Stoplight::Light.new(name) {} }
  let(:name) { ('a'..'z').to_a.shuffle.join }
  let(:failure) { Stoplight::Failure.new('class', 'message', Time.new - 10) }
  let(:other) { Stoplight::Failure.new('class', 'message 2', Time.new) }

  it_behaves_like Stoplight::Strategy::Base
  it_behaves_like 'Stoplight::Strategy::Base#clear_failures'
  it_behaves_like 'Stoplight::Strategy::Base#get_all'
  it_behaves_like 'Stoplight::Strategy::Base#get_failures'
  it_behaves_like 'Stoplight::Strategy::Base#record_failure'
end
