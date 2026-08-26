# frozen_string_literal: true

RSpec.describe Stoplight::Admin, :redis, type: %i[request] do
  let(:light) { system.register(light_name) }
  let(:light_name) { SecureRandom.uuid }
  let(:id) { Stoplight::Domain::Id.for(light_name) }
  let(:light_id) { id }
  let(:light_condition) { proc { 1 / 1 == 0 } }
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

  describe ".add_system" do
    it "raises for a non-persistent system" do
      non_persistent_system = instance_double(Stoplight::Wiring::System, persistent?: false)

      expect { Stoplight::Admin.add_system(non_persistent_system) }
        .to raise_error(TypeError, /Stoplight Admin requires a persistent data store/)
    end
  end

  describe ".__stoplight__reset_systems!" do
    it "clears every explicitly added system" do
      expect(Stoplight::Admin.settings.systems).to eq([system])

      Stoplight::Admin.__stoplight__reset_systems!

      expect(Stoplight::Admin.settings.systems).to eq([Stoplight.__stoplight__default_system])
    end
  end

  describe ".systems" do
    context "when no system has been explicitly added" do
      before { Stoplight::Admin.__stoplight__reset_systems! }

      it "raises if the default system is not persistent" do
        allow(Stoplight).to receive(:__stoplight__default_system)
          .and_return(instance_double(Stoplight::Wiring::System, persistent?: false))

        expect { Stoplight::Admin.settings.systems }
          .to raise_error(TypeError, /Stoplight Admin requires a persistent data store/)
      end
    end
  end

  describe "multi-system isolation" do
    let(:other_data_store) { Stoplight::DataStore::Redis.new(redis) }
    let(:other_system) { Stoplight.register_system(SecureRandom.uuid, data_store: other_data_store) }
    let(:other_light_name) { SecureRandom.uuid }
    let(:other_light) { other_system.register(other_light_name) }
    let(:other_light_id) { Stoplight::Domain::Id.for(other_light_name) }

    before do
      Stoplight::Admin.add_system(other_system)
      light.run(&light_condition)
      other_light.run(&light_condition)
    end

    it "scopes GET /systems/{system_id}/lights.json to the requested system's lights" do
      get "/systems/#{system_id}/lights.json"

      expect(response_body.fetch("lights").map { |h| h.fetch("name") }).to contain_exactly(light_name)
    end

    it "does not unlock a light belonging to another system" do
      other_light.lock(Stoplight::Color::GREEN)

      patch "/systems/#{system_id}/lights/#{other_light_id}/unlock"

      expect(last_response.status).to eq(404)
      expect(other_light.state).to eq("locked_green")
    end

    it "does not lock a light belonging to another system" do
      patch "/systems/#{system_id}/lights/#{other_light_id}/lock", color: "green"

      expect(last_response.status).to eq(404)
      expect(other_light.state).to eq("unlocked")
    end

    it "bulk-locks only the requested system's lights" do
      light.lock(Stoplight::Color::RED)
      other_light.lock(Stoplight::Color::RED)

      patch "/systems/#{system_id}/lights/lock", color: "green"

      expect(last_response.status).to eq(302)
      expect(light.state).to eq("locked_green")
      expect(other_light.state).to eq("locked_red")
    end

    it "does not delete a light belonging to another system" do
      delete "/systems/#{system_id}/lights/#{other_light_id}"

      expect(last_response.status).to eq(404)

      get "/systems/#{other_system.config.id}/lights.json"
      expect(response_body.fetch("lights").map { |h| h.fetch("name") }).to contain_exactly(other_light_name)
    end
  end

  describe "GET /" do
    it "redirects to first system's lights" do
      get "/"

      expect(last_response.status).to eq(302)
      expect(last_response.headers["location"]).to include("#{last_request.env["HTTP_HOST"]}/systems/#{system_id}/lights")
    end

    context "with more than one system configured" do
      let(:other_data_store) { Stoplight::DataStore::Redis.new(redis) }
      let(:other_system) { Stoplight.register_system(SecureRandom.uuid, data_store: other_data_store) }

      before { Stoplight::Admin.add_system(other_system) }

      it "redirects to the first-registered system's lights, not the last" do
        get "/"

        expect(last_response.status).to eq(302)
        expect(last_response.headers["location"]).to include("/systems/#{system_id}/lights")
        expect(last_response.headers["location"]).not_to include("/systems/#{other_system.config.id}/lights")
      end
    end
  end

  describe "GET /systems/{system_id}/lights" do
    context "when system is not added to admin" do
      let(:system_id) { "deadbeaf" }

      it "renders not found error" do
        get "/systems/#{system_id}/lights"

        expect(last_response).to be_not_found
      end
    end

    context "when system is added" do
      it "renders favicon, svg icon, and apple-touch-icon links with cache-busting digests" do
        get "/systems/#{system_id}/lights"

        expect(last_response).to be_ok

        host = last_request.env["HTTP_HOST"]
        digests = Stoplight::Admin::ASSET_DIGESTS

        expect(last_response.body).to include(%(<link rel="icon" href="http://#{host}/favicon.ico?v=#{digests.fetch("favicon.ico")}" sizes="32x32">))
        expect(last_response.body).to include(%(<link rel="icon" href="http://#{host}/icon.svg?v=#{digests.fetch("icon.svg")}" type="image/svg+xml">))
        expect(last_response.body).to include(%(<link rel="apple-touch-icon" href="http://#{host}/apple-touch-icon.png?v=#{digests.fetch("apple-touch-icon.png")}">))
      end

      context "with no lights" do
        it "renders home page correctly" do
          get "/systems/#{system_id}/lights"

          expect(last_response).to be_ok
          expect(last_response.body).to include("Stoplight Admin")
          expect(last_response.body).to include("No lights found")
          expect(last_response.body).to include("Ensure lights are registered and this Admin instance uses the same data store as your application.")
          expect(last_response.body).to include("Refresh Lights")
        end
      end

      context "with some lights" do
        before { light.run(&light_condition) }

        it "renders home page correctly" do
          get "/systems/#{system_id}/lights"

          expect(last_response).to be_ok

          expect(last_response.body).to include("Healthy")
          expect(last_response.body).to include("No recent errors")
          expect(last_response.body).to include("Operating normally")
          expect(last_response.body).to include("Unlock")
          expect(last_response.body).to include("Lock Red")
          expect(last_response.body).to include("Lock Green")
          expect(last_response.body).to include("Failures")

          expect(last_response.body).to_not include("No lights found")
          expect(last_response.body).not_to include("Ensure lights are registered and this Admin instance uses the same data store as your application.")
        end

        it "links the light actions" do
          get "/systems/#{system_id}/lights"

          expect(last_response).to be_ok

          expect(last_response.body).to include(%(href="http://#{last_request.env["HTTP_HOST"]}/systems/#{system_id}/lights/#{light_id}/unlock" data-turbo-method="patch"))
          expect(last_response.body).to include(%(href="http://#{last_request.env["HTTP_HOST"]}/systems/#{system_id}/lights/#{light_id}/lock?color=green" data-turbo-method="patch"))
          expect(last_response.body).to include(%(href="http://#{last_request.env["HTTP_HOST"]}/systems/#{system_id}/lights/#{light_id}/lock?color=red" data-turbo-method="patch"))

          expect(last_response.body).to_not include("Read-only")
        end

        it "asks for confirmation before removing a light, and only before removing" do
          get "/systems/#{system_id}/lights"

          expect(last_response).to be_ok

          expect(last_response.body).to include(
            %(href="http://#{last_request.env["HTTP_HOST"]}/systems/#{system_id}/lights/#{light_id}" data-turbo-method="delete" data-turbo-confirm="Are you sure you want to remove this light?")
          )
          expect(last_response.body.scan("data-turbo-confirm").count).to eq(1)
        end
      end

      context "with a light that is not green" do
        before { light.lock(Stoplight::Color::RED) }

        it "links Lock All Green" do
          get "/systems/#{system_id}/lights"

          expect(last_response).to be_ok
          expect(last_response.body).to include(%(href="http://#{last_request.env["HTTP_HOST"]}/systems/#{system_id}/lights/lock?color=green" data-turbo-method="patch"))
        end
      end

      context "when the light's name contains HTML" do
        let(:light_name) { %(<script>alert("xss")</script>) }

        before { light.run(&light_condition) }

        it "escapes the light's name" do
          get "/systems/#{system_id}/lights"

          expect(last_response).to be_ok
          expect(last_response.body).not_to include(light_name)
          expect(last_response.body).to include(CGI.escapeHTML(light_name))
        end
      end

      context "when light has multiple consecutive failures" do
        let(:light) { system.register(SecureRandom.uuid) }

        before do
          3.times do
            light.run(->(_) {}) { raise "whoops" }
          end
        end

        it "displays the correct failure count" do
          get "/systems/#{system_id}/lights"

          expect(last_response).to be_ok

          expect(last_response.body).to include(">Failures:</span> 3")
        end
      end

      context "when the latest failure's message contains HTML" do
        let(:light) { system.register(SecureRandom.uuid) }
        let(:failure_message) { %(<script>alert("xss")</script>) }

        before { 3.times { light.run(->(_) {}) { raise failure_message } } }

        it "escapes the failure message in the light's description" do
          get "/systems/#{system_id}/lights"

          expect(last_response).to be_ok
          expect(last_response.body).not_to include(failure_message)
          expect(last_response.body).to include(CGI.escapeHTML(failure_message))
        end
      end
    end
  end

  describe "system switcher" do
    context "with a single system configured" do
      it "does not render the switcher" do
        get "/systems/#{system_id}/lights"

        expect(last_response).to be_ok
        expect(last_response.body).not_to include("systemMenuButton")
      end
    end

    context "with more than one system configured" do
      let(:other_data_store) { Stoplight::DataStore::Redis.new(redis) }
      let(:other_system) { Stoplight.register_system(SecureRandom.uuid, data_store: other_data_store) }
      before { Stoplight::Admin.add_system(other_system) }

      it "renders a switcher button and menu listing every configured system" do
        get "/systems/#{system_id}/lights"

        expect(last_response).to be_ok
        expect(last_response.body).to include("systemMenuButton")
        expect(last_response.body).to include(system.name)
        expect(last_response.body).to include(other_system.name)
      end

      it "links each menu row to that system's dashboard" do
        get "/systems/#{system_id}/lights"

        host = last_request.env["HTTP_HOST"]
        expect(last_response.body).to include(%(href="http://#{host}/systems/#{other_system.config.id}/lights"))
      end

      it "highlights the current system's row in the menu" do
        get "/systems/#{system_id}/lights"

        host = last_request.env["HTTP_HOST"]
        expect(last_response.body).to include(
          %(href="http://#{host}/systems/#{system_id}/lights" class="block px-4 py-2 bg-blue-50 text-blue-700)
        )
        expect(last_response.body).to include(
          %(href="http://#{host}/systems/#{other_system.config.id}/lights" class="block px-4 py-2 hover:bg-gray-100)
        )
      end
    end

    context "when a system's name contains HTML" do
      let(:other_data_store) { Stoplight::DataStore::Redis.new(redis) }
      let(:other_system_name) { %(<script>alert("xss")</script>) }
      let(:other_system) { Stoplight.register_system(other_system_name, data_store: other_data_store) }

      before { Stoplight::Admin.add_system(other_system) }

      it "escapes the other system's name in the switcher menu" do
        get "/systems/#{system_id}/lights"

        expect(last_response).to be_ok
        expect(last_response.body).not_to include(other_system_name)
        expect(last_response.body).to include(CGI.escapeHTML(other_system_name))
      end
    end
  end

  describe "GET /stats" do
    context "with no lights" do
      it "returns expected response" do
        get "/stats"

        expect(last_response).to be_ok
        expect(response_body)
          .to eq(
            {
              "stats" =>
                {"count_red" => 0,
                 "count_yellow" => 0,
                 "count_green" => 0,
                 "percent_red" => 0,
                 "percent_yellow" => 0,
                 "percent_green" => 0},
              "lights" => []
            }
          )
      end
    end

    context "with some lights" do
      before { light.run(&light_condition) }

      it "returns lights of the first system" do
        get "/stats"

        expect(last_response).to be_ok

        expect(response_body).to eq(
          {
            "stats" =>
              {"count_red" => 0,
               "count_yellow" => 0,
               "count_green" => 1,
               "percent_red" => 0,
               "percent_yellow" => 0,
               "percent_green" => 100},
            "lights" => [
              {"id" => id, "color" => "green", "failures" => [], "locked" => false, "name" => light_name}
            ]
          }
        )
      end
    end

    context "with more than one system configured" do
      let(:other_data_store) { Stoplight::DataStore::Redis.new(redis) }
      let(:other_system) { Stoplight.register_system(SecureRandom.uuid, data_store: other_data_store) }
      let(:other_light) { other_system.register(SecureRandom.uuid) }

      before do
        Stoplight::Admin.add_system(other_system)
        other_light.run { "ok" }
      end

      it "returns only the first-registered system's lights, not the last" do
        get "/stats"

        expect(last_response).to be_ok
        other_light_id = Stoplight::Domain::Id.for(other_light.name)
        expect(response_body["lights"].map { |light| light["id"] }).not_to include(other_light_id)
      end
    end
  end

  describe "GET /systems/{system_id}/lights.json" do
    it "returns not found for an unknown system_id" do
      get "/systems/deadbeaf/lights.json"

      expect(last_response).to be_not_found
    end

    context "with no lights" do
      it "returns expected response" do
        get "/systems/#{system_id}/lights.json"

        expect(last_response).to be_ok
        expect(response_body)
          .to eq(
            {
              "stats" =>
                {"count_red" => 0,
                 "count_yellow" => 0,
                 "count_green" => 0,
                 "percent_red" => 0,
                 "percent_yellow" => 0,
                 "percent_green" => 0},
              "lights" => []
            }
          )
      end
    end

    context "with some lights" do
      before { light.run(&light_condition) }

      it "returns expected response" do
        get "/systems/#{system_id}/lights.json"

        expect(last_response).to be_ok

        expect(response_body).to eq(
          {
            "stats" =>
              {"count_red" => 0,
               "count_yellow" => 0,
               "count_green" => 1,
               "percent_red" => 0,
               "percent_yellow" => 0,
               "percent_green" => 100},
            "lights" => [
              {"id" => id, "color" => "green", "failures" => [], "locked" => false, "name" => light_name}
            ]
          }
        )
      end
    end
  end

  describe "PATCH /systems/{system_id}/lights/{light_id}/unlock" do
    before do
      light.run(&light_condition)
      light.lock(Stoplight::Color::GREEN)
    end

    it "unlocks the light" do
      patch "/systems/#{system_id}/lights/#{id}/unlock"

      expect(last_response.status).to eq(302)
      expect(last_response.headers["location"]).to include("#{last_request.env["HTTP_HOST"]}/systems/#{system_id}/lights")
      expect(light.state).to eq "unlocked"
    end

    it "cannot unlock non-existent light" do
      patch "/systems/#{system_id}/lights/#{SecureRandom.uuid}/unlock"

      expect(last_response.status).to eq(404)
    end

    it "returns not found for an unknown system_id" do
      patch "/systems/deadbeaf/lights/#{light_id}/unlock"

      expect(last_response).to be_not_found
    end
  end

  describe "PATCH /systems/{system_id}/lights/{light_id}/lock" do
    before { light.run(&light_condition) }

    it "locks the light green" do
      patch "/systems/#{system_id}/lights/#{light_id}/lock", color: "green"

      expect(last_response.status).to eq(302)
      expect(last_response.headers["location"]).to include("#{last_request.env["HTTP_HOST"]}/systems/#{system_id}/lights")
      expect(light.state).to eq "locked_green"
    end

    it "locks the light red" do
      patch "/systems/#{system_id}/lights/#{light_id}/lock", color: "red"

      expect(last_response.status).to eq(302)
      expect(last_response.headers["location"]).to include("#{last_request.env["HTTP_HOST"]}/systems/#{system_id}/lights")
      expect(light.state).to eq "locked_red"
    end

    it "cannot lock non-existent light" do
      patch "/systems/#{system_id}/lights/#{SecureRandom.uuid}/lock", color: "green"

      expect(last_response.status).to eq(404)
    end

    it "returns not found for an unknown system_id" do
      patch "/systems/deadbeaf/lights/#{light_id}/lock", color: "green"

      expect(last_response).to be_not_found
    end
  end

  describe "PATCH /systems/{system_id}/lights/lock" do
    let(:another_light) { system.register("bar") }
    let(:green_light) { system.register("baz") }

    before do
      [light, another_light].each do |light|
        light.lock(Stoplight::Color::RED)
      end
    end

    it "locks non-green lights" do
      patch "/systems/#{system_id}/lights/lock", color: "green"

      expect(last_response.status).to eq(302)
      expect(last_response.headers["location"]).to include("#{last_request.env["HTTP_HOST"]}/systems/#{system_id}/lights")

      [light, another_light].each do |light|
        expect(light.state).to eq "locked_green"
      end
    end

    it "does not lock green lights" do
      patch "/systems/#{system_id}/lights/lock", color: "green"

      expect(last_response.status).to eq(302)
      expect(last_response.headers["location"]).to include("#{last_request.env["HTTP_HOST"]}/systems/#{system_id}/lights")
      expect(green_light.state).to_not eq("locked_green")
    end

    it "refuses to bulk-lock lights to any color other than green" do
      patch "/systems/#{system_id}/lights/lock", color: "red"

      expect(last_response.status).to eq(400)
      expect(light.state).to eq("locked_red")
    end

    it "returns not found for an unknown system_id" do
      patch "/systems/deadbeaf/lights/lock", color: "green"

      expect(last_response).to be_not_found
    end
  end

  describe "DELETE /systems/{system_id}/lights/{light_id}" do
    let(:another_light) { system.register("bar") }

    before do
      [light, another_light].each do |l|
        l.run(->(_) {}) { raise "whoops" }
      end
    end

    it "removes the specified light metadata and redirects" do
      delete "/systems/#{system_id}/lights/#{light_id}"

      expect(last_response.status).to eq(302)
      expect(last_response.headers["location"]).to include("#{last_request.env["HTTP_HOST"]}/")

      get "/systems/#{system_id}/lights.json"
      expect(last_response).to be_ok
      expect(response_body.fetch("lights").map { |h| h.fetch("name") }).to contain_exactly("bar")
    end

    it "returns not found for an unknown system_id" do
      delete "/systems/deadbeaf/lights/#{light_id}"

      expect(last_response).to be_not_found
    end
  end

  context "when the admin panel is read-only" do
    around do |example|
      previous_setting = Stoplight::Admin.settings.read_only
      Stoplight::Admin.set :read_only, true
      example.run
    ensure
      Stoplight::Admin.set :read_only, previous_setting
    end

    describe "GET /systems/{system_id}/lights" do
      before { light.run(&light_condition) }

      it "tells the operator the panel is read-only" do
        get "/systems/#{system_id}/lights"

        expect(last_response).to be_ok
        expect(last_response.body).to include("Read-only")
      end

      it "renders the light actions without links" do
        get "/systems/#{system_id}/lights"

        expect(last_response).to be_ok
        expect(last_response.body).to include("Unlock", "Lock Red", "Lock Green", "Remove")

        expect(last_response.body).to_not include("/#{light_id}/unlock")
        expect(last_response.body).to_not include("/#{light_id}/lock")
      end

      context "when some lights are not green" do
        before { light.lock(Stoplight::Color::RED) }

        it "renders Lock All Green without a link" do
          get "/systems/#{system_id}/lights"

          expect(last_response).to be_ok
          expect(last_response.body).to include("Lock All Green")
          expect(last_response.body).to_not include("/lock?color=green")
        end
      end
    end

    describe "GET /stats" do
      before { light.run(&light_condition) }

      it "serves the stats" do
        get "/stats"

        expect(last_response).to be_ok
        expect(response_body.fetch("lights").map { |h| h.fetch("name") }).to contain_exactly(light_name)
      end
    end

    it "serves HEAD requests" do
      head "/systems/#{system_id}/lights"

      expect(last_response).to be_ok
    end

    it "refuses a verb it has no route for, rather than only the ones it does" do
      delete "/green"

      expect(last_response.status).to eq(403)
    end

    describe "PATCH /systems/{system_id}/lights/{light_id}/unlock" do
      before do
        light.run(&light_condition)
        light.lock(Stoplight::Color::GREEN)
      end

      it "refuses to unlock the light" do
        patch "/systems/#{system_id}/lights/#{light_id}/unlock"

        expect(last_response.status).to eq(403)
        expect(last_response.body).to include("read-only mode")
        expect(light.state).to eq("locked_green")
      end
    end

    describe "PATCH /systems/{system_id}/lights/{light_id}/lock" do
      before { light.run(&light_condition) }

      it "refuses to lock the light" do
        patch "/systems/#{system_id}/lights/#{light_id}/lock"

        expect(last_response.status).to eq(403)
        expect(light.state).to eq("unlocked")
      end
    end

    describe "PATCH /systems/{system_id}/lights/lock" do
      before { light.lock(Stoplight::Color::RED) }

      it "refuses to lock the lights" do
        patch "/systems/#{system_id}/lights/lock"

        expect(last_response.status).to eq(403)
        expect(light.state).to eq("locked_red")
      end
    end

    describe "DELETE /systems/{system_id}/lights/{light_id}" do
      before do
        light.run(->(_) {}) { raise "whoops" }
      end

      it "refuses to remove the light" do
        delete "/systems/#{system_id}/lights/#{light_id}"

        expect(last_response.status).to eq(403)

        get "/systems/#{system_id}/lights.json"
        expect(response_body.fetch("lights").map { |h| h.fetch("id") }).to contain_exactly(id)
      end
    end
  end
end
