# frozen_string_literal: true

require "nokogiri"

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

  describe "GET /systems/:system_id/lights" do
    def document
      Nokogiri::HTML5(last_response.body)
    end

    it "responds with 404 for a system that is not configured" do
      get "/systems/unknown/lights"

      expect(last_response.status).to eq(404)
    end

    it "lists registered lights by name instead of the empty state" do
      system.register("checkout")

      get "/systems/#{system_id}/lights"

      expect(document.css('[data-role="light-row"]').map { |row| row["data-light"] }).to eq(["checkout"])
      expect(document.css('[data-role="empty-state"]')).to be_empty
    end

    it "lists only the lights of the requested system" do
      other_system = Stoplight.register_system(SecureRandom.uuid, data_store: data_store)
      Stoplight::Admin.add_system(other_system)
      other_system.register("reporting")
      system.register("checkout")

      get "/systems/#{other_system.config.id}/lights"

      expect(document.css('[data-role="light-row"]').map { |row| row["data-light"] }).to eq(["reporting"])
    end

    it "escapes light names" do
      system.register("<b>checkout</b>")

      get "/systems/#{system_id}/lights"

      expect(last_response.body).not_to include("<b>checkout</b>")
      expect(document.at_css('[data-role="light-row"]').text.strip).to eq("<b>checkout</b>")
    end

    context "when no middleware vets the forwarded host" do
      let(:app) { described_class.new! }

      it "keeps a forwarded host out of the page" do
        get "/systems/#{system_id}/lights", {}, "HTTP_X_FORWARDED_HOST" => %(evil.example"><svg/onload=alert(1)>)

        expect(last_response).to be_ok
        expect(last_response.body).not_to include("onload")
      end
    end

    it "serves every stylesheet and script the page links to" do
      get "/systems/#{system_id}/lights"

      asset_urls = document.css("link[rel=stylesheet]").map { |link| link["href"] } +
        document.css("script[src]").map { |script| script["src"] }

      expect(asset_urls).not_to be_empty
      asset_urls.each do |asset_url|
        uri = URI(asset_url)
        get "#{uri.path}?#{uri.query}"

        expect(last_response.status).to eq(200), "#{asset_url} responded with #{last_response.status}"
      end
    end
  end

  describe "read-only mode" do
    around do |example|
      Stoplight::Admin.configure { |config| config.read_only = true }
      example.run
      Stoplight::Admin.configure { |config| config.read_only = false }
    end

    %i[post put patch delete].each do |verb|
      it "refuses #{verb.upcase} even on paths it does not route" do
        public_send(verb, "/systems/#{system_id}/lights")

        expect(last_response.status).to eq(403)
      end
    end

    it "still serves reads" do
      get "/systems/#{system_id}/lights"

      expect(last_response.status).to eq(200)
    end

    it "still answers HEAD requests" do
      head "/systems/#{system_id}/lights"

      expect(last_response.status).to eq(200)
    end
  end
end
