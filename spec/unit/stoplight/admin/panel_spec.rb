# frozen_string_literal: true

RSpec.describe Stoplight::Admin::Panel, :redis, type: %i[request] do
  let(:data_store) { Stoplight::DataStore::Redis.new(redis) }
  let(:system) { Stoplight.register_system(SecureRandom.uuid, data_store:) }
  let(:system_id) { system.config.id }

  before do
    Stoplight.configure(trust_me_im_an_engineer: true) do |config|
      config.data_store = data_store
    end
    Stoplight::Admin.add_system(system)
  end

  after do
    Stoplight::Admin.__stoplight__reset_systems!
  end

  describe "GET /" do
    it "keeps the mount prefix when redirecting to the first system" do
      get "/", {}, "SCRIPT_NAME" => "/stoplights"

      expect(last_response).to be_redirect
      expect(URI(last_response.location).path).to eq("/stoplights/systems/#{system_id}/lights")
    end
  end
end
