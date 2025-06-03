# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stoplight::Admin, type: %i[request] do
  let(:light) { Stoplight("foo") }
  let(:light_condition) { proc { 1 / 1 == 0 } }

  before do
    redis_instance = Redis.new(url: ENV.fetch("STOPLIGHT_REDIS_URL", "redis://127.0.0.1:6379/0"))
    Stoplight.reset_config!
    Stoplight.configure do |config|
      config.data_store = Stoplight::DataStore::Redis.new(redis_instance)
    end
    redis_instance.flushall
  end

  describe "GET /" do
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
                {"color" => "green", "failures" => [nil], "locked" => false, "name" => "foo"}
              ]
            }
          )
      end
    end
  end

  describe "POST /unlock" do
    before do
      light.run(&light_condition)
      light.lock(Stoplight::Color::GREEN)
    end

    it "locks the light" do
      post "/unlock", names: "foo"

      expect(last_response.status).to eq(302)
      expect(last_response.headers["location"]).to include("#{last_request.env["HTTP_HOST"]}/")
      expect(light.state).to eq "unlocked"
    end
  end

  describe "POST /green" do
    before { light.run(&light_condition) }

    it "locks the light" do
      post "/green", names: "foo"

      expect(last_response.status).to eq(302)
      expect(last_response.headers["location"]).to include("#{last_request.env["HTTP_HOST"]}/")
      expect(light.state).to eq "locked_green"
    end
  end

  describe "POST /red" do
    before { light.run(&light_condition) }

    it "locks the light" do
      post "/red", names: "foo"

      expect(last_response.status).to eq(302)
      expect(last_response.headers["location"]).to include("#{last_request.env["HTTP_HOST"]}/")
      expect(light.state).to eq "locked_red"
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
end
