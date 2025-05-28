# frozen_string_literal: true
ENV['APP_ENV'] = 'test'

require "rack/test"

RSpec.describe Stoplight::Admin do
  include Rack::Test::Methods
  def app
    Stoplight::Admin
  end

  it "says hello" do
    get '/'
    # expect(last_response).to be_ok
    expect(last_response.body).to eq('Hello World')
  end
end
