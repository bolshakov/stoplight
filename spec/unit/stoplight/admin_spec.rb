# frozen_string_literal: true

RSpec.describe Stoplight::Admin, :redis, type: %i[request] do
  let(:light) { Stoplight("foo") }
  let(:id) { Stoplight::Domain::Id.for("foo") }
  let(:light_id) { id }
  let(:light_condition) { proc { 1 / 1 == 0 } }

  before do
    Stoplight.configure(trust_me_im_an_engineer: true) do |config|
      config.data_store = Stoplight::DataStore::Redis.new(redis)
    end
  end

  describe "GET /" do
    it "renders favicon, svg icon, and apple-touch-icon links with cache-busting digests" do
      get "/"

      expect(last_response).to be_ok

      host = last_request.env["HTTP_HOST"]
      digests = Stoplight::Admin::ASSET_DIGESTS

      expect(last_response.body).to include(%(<link rel="icon" href="http://#{host}/favicon.ico?v=#{digests.fetch("favicon.ico")}" sizes="32x32">))
      expect(last_response.body).to include(%(<link rel="icon" href="http://#{host}/icon.svg?v=#{digests.fetch("icon.svg")}" type="image/svg+xml">))
      expect(last_response.body).to include(%(<link rel="apple-touch-icon" href="http://#{host}/apple-touch-icon.png?v=#{digests.fetch("apple-touch-icon.png")}">))
    end

    context "with no lights" do
      it "renders home page correctly" do
        get "/"

        expect(last_response).to be_ok
        expect(last_response.body).to include("Stoplight Admin")
        expect(last_response.body).to include("No lights found")
        expect(last_response.body).to include("Ensure that your Stoplight data store is properly configured and that your Stoplight blocks have been run.")
        expect(last_response.body).to include("Refresh Lights")
      end
    end

    context "with some lights" do
      before { light.run(&light_condition) }

      it "renders home page correctly" do
        get "/"

        expect(last_response).to be_ok

        expect(last_response.body).to include("Healthy")
        expect(last_response.body).to include("No recent errors")
        expect(last_response.body).to include("Operating normally")
        expect(last_response.body).to include("Unlock")
        expect(last_response.body).to include("Lock Red")
        expect(last_response.body).to include("Lock Green")
        expect(last_response.body).to include("Failures")

        expect(last_response.body).to_not include("No lights found")
        expect(last_response.body).not_to include("Ensure that your Stoplight data store is properly configured and that your Stoplight blocks have been run.")
      end

      it "links the light actions" do
        get "/"

        expect(last_response).to be_ok

        expect(last_response.body).to include(%(href="http://#{last_request.env["HTTP_HOST"]}/#{light_id}/unlock" data-turbo-method="patch"))
        expect(last_response.body).to include(%(href="http://#{last_request.env["HTTP_HOST"]}/#{light_id}/lock?color=green" data-turbo-method="patch"))
        expect(last_response.body).to include(%(href="http://#{last_request.env["HTTP_HOST"]}/#{light_id}/lock?color=red" data-turbo-method="patch"))

        expect(last_response.body).to_not include("Read-only")
      end

      it "asks for confirmation before removing a light, and only before removing" do
        get "/"

        expect(last_response).to be_ok

        expect(last_response.body).to include(
          %(href="http://#{last_request.env["HTTP_HOST"]}/#{light_id}" data-turbo-method="delete" data-turbo-confirm="Are you sure you want to remove this light?")
        )
        expect(last_response.body.scan("data-turbo-confirm").count).to eq(1)
      end
    end

    context "with a light that is not green" do
      before { light.lock(Stoplight::Color::RED) }

      it "links Lock All Green" do
        get "/"

        expect(last_response).to be_ok
        expect(last_response.body).to include(%(href="http://#{last_request.env["HTTP_HOST"]}/green_all" data-turbo-method="post"))
      end
    end

    context "when light has multiple consecutive failures" do
      let(:light) { Stoplight("failing") }

      before do
        3.times do
          light.run { raise "whoops" }
        rescue
          nil
        end
      end

      it "displays the correct failure count" do
        get "/"

        expect(last_response).to be_ok

        expect(last_response.body).to include(">Failures:</span> 3")
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

      it "returns expected response" do
        get "/stats"

        expect(last_response).to be_ok

        expect(response_body)
          .to eq(
            {
              "stats" =>
                {"count_red" => 0,
                 "count_yellow" => 0,
                 "count_green" => 1,
                 "percent_red" => 0,
                 "percent_yellow" => 0,
                 "percent_green" => 100},
              "lights" => [
                {"id" => id, "color" => "green", "failures" => [], "locked" => false, "name" => "foo"}
              ]
            }
          )
      end
    end
  end

  describe "PATCH /{light_id}/unlock" do
    before do
      light.run(&light_condition)
      light.lock(Stoplight::Color::GREEN)
    end

    it "unlocks the light" do
      patch "/#{id}/unlock"

      expect(last_response.status).to eq(302)
      expect(last_response.headers["location"]).to include("#{last_request.env["HTTP_HOST"]}/")
      expect(light.state).to eq "unlocked"
    end

    it "cannot unlock non-existent light" do
      patch "/#{SecureRandom.uuid}/unlock"

      expect(last_response.status).to eq(404)
    end
  end

  describe "PATCH /{light_id}/lock" do
    before { light.run(&light_condition) }

    it "locks the light green" do
      patch "/#{light_id}/lock", color: "green"

      expect(last_response.status).to eq(302)
      expect(last_response.headers["location"]).to include("#{last_request.env["HTTP_HOST"]}/")
      expect(light.state).to eq "locked_green"
    end

    it "locks the light red" do
      patch "/#{light_id}/lock", color: "red"

      expect(last_response.status).to eq(302)
      expect(last_response.headers["location"]).to include("#{last_request.env["HTTP_HOST"]}/")
      expect(light.state).to eq "locked_red"
    end

    it "cannot lock non-existent light" do
      patch "/#{SecureRandom.uuid}/lcok", color: "green"

      expect(last_response.status).to eq(404)
    end
  end

  describe "POST /green_all" do
    let(:another_light) { Stoplight("bar") }
    let(:green_light) { Stoplight("baz") }

    before do
      [light, another_light].each do |light|
        light.lock(Stoplight::Color::RED)
      end
    end

    it "locks non-green lights" do
      post "/green_all"

      expect(last_response.status).to eq(302)
      expect(last_response.headers["location"]).to include("#{last_request.env["HTTP_HOST"]}/")

      [light, another_light].each do |light|
        expect(light.state).to eq "locked_green"
      end
    end

    it "does not lock green lights" do
      post "/green_all"

      expect(last_response.status).to eq(302)
      expect(last_response.headers["location"]).to include("#{last_request.env["HTTP_HOST"]}/")
      expect(green_light.state).to_not eq("locked_green")
    end
  end

  describe "DELETE /{light_id}" do
    let(:another_light) { Stoplight("bar") }

    before do
      [light, another_light].each do |l|
        l.run { raise "whoops" }
      rescue
        nil
      end
    end

    it "removes the specified light metadata and redirects" do
      delete "/#{light_id}"

      expect(last_response.status).to eq(302)
      expect(last_response.headers["location"]).to include("#{last_request.env["HTTP_HOST"]}/")

      get "/stats"
      expect(last_response).to be_ok
      expect(response_body.fetch("lights").map { |h| h.fetch("name") }).to contain_exactly("bar")
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

    describe "GET /" do
      before { light.run(&light_condition) }

      it "tells the operator the panel is read-only" do
        get "/"

        expect(last_response).to be_ok
        expect(last_response.body).to include("Read-only")
      end

      it "renders the light actions without links" do
        get "/"

        expect(last_response).to be_ok
        expect(last_response.body).to include("Unlock", "Lock Red", "Lock Green", "Remove")

        expect(last_response.body).to_not include("/#{light_id}/unlock")
        expect(last_response.body).to_not include("/#{light_id}/lock")
      end

      context "when some lights are not green" do
        before { light.lock(Stoplight::Color::RED) }

        it "renders Lock All Green without a link" do
          get "/"

          expect(last_response).to be_ok
          expect(last_response.body).to include("Lock All Green")
          expect(last_response.body).to_not include("/green_all")
        end
      end
    end

    describe "GET /stats" do
      before { light.run(&light_condition) }

      it "serves the stats" do
        get "/stats"

        expect(last_response).to be_ok
        expect(response_body.fetch("lights").map { |h| h.fetch("name") }).to contain_exactly("foo")
      end
    end

    it "serves HEAD requests" do
      head "/"

      expect(last_response).to be_ok
    end

    it "refuses a verb it has no route for, rather than only the ones it does" do
      delete "/green"

      expect(last_response.status).to eq(403)
    end

    describe "PATCH /{light_id}/unlock" do
      before do
        light.run(&light_condition)
        light.lock(Stoplight::Color::GREEN)
      end

      it "refuses to unlock the light" do
        patch "/#{light_id}/unlock"

        expect(last_response.status).to eq(403)
        expect(last_response.body).to include("read-only mode")
        expect(light.state).to eq("locked_green")
      end
    end

    describe "PATCH /{light_id}/lock" do
      before { light.run(&light_condition) }

      it "refuses to lock the light" do
        patch "/#{light_id}/lock"

        expect(last_response.status).to eq(403)
        expect(light.state).to eq("unlocked")
      end
    end

    describe "POST /green_all" do
      before { light.lock(Stoplight::Color::RED) }

      it "refuses to lock the lights" do
        post "/green_all"

        expect(last_response.status).to eq(403)
        expect(light.state).to eq("locked_red")
      end
    end

    describe "DELETE /{light_id}" do
      before do
        light.run { raise "whoops" }
      rescue
        nil
      end

      it "refuses to remove the light" do
        delete "/#{light_id}"

        expect(last_response.status).to eq(403)

        get "/stats"
        expect(response_body.fetch("lights").map { |h| h.fetch("id") }).to contain_exactly(id)
      end
    end
  end
end
