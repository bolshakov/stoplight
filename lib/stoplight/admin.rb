# frozen_string_literal: true

require "sinatra"
require "sinatra/contrib"
require "sinatra/base"
require "sinatra/json"

module Stoplight
  module Admin
    COLORS = [
      GREEN = Stoplight::Color::GREEN,
      YELLOW = Stoplight::Color::YELLOW,
      RED = Stoplight::Color::RED
    ].freeze
    private_constant :COLORS

    def self.registered(app)
      app.helpers Helpers

      app.set :data_store, nil
      app.set :views, File.join(File.dirname(__FILE__), "views")

      app.get "/" do
        lights, stats = dependencies.home_action.call

        erb :index, locals: stats.merge(lights: lights)
      end

      app.get "/stats" do
        lights, stats = dependencies.stats_action.call

        json({stats: stats, lights: lights.map(&:as_json)})
      end

      app.post "/lock" do
        dependencies.lock_action.call(params)

        redirect to("/")
      end

      app.post "/unlock" do
        dependencies.unlock_action.call(params)

        redirect to("/")
      end

      app.post "/green" do
        dependencies.green_action.call(params)

        redirect to("/")
      end

      app.post "/red" do
        dependencies.red_action.call(params)

        redirect to("/")
      end

      app.post "/green_all" do
        dependencies.green_all_action.call

        redirect to("/")
      end
    end
  end
end

register Stoplight::Admin
