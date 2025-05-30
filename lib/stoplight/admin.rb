# frozen_string_literal: true

require "sinatra"
require "sinatra/contrib"
require "sinatra/base"
require "sinatra/json"

module Stoplight
  class Admin < Sinatra::Base
    COLORS = [
      GREEN = Stoplight::Color::GREEN,
      YELLOW = Stoplight::Color::YELLOW,
      RED = Stoplight::Color::RED
    ].freeze
    private_constant :COLORS

    helpers Helpers

    set :data_store, Proc.new {Stoplight.config_provider.data_store }
    set :views, File.join(__dir__, "admin", "views")

    get "/" do
      lights, stats = dependencies.stats_action.call

      erb :index, locals: stats.merge(lights: lights)
    end

    get "/stats" do
      lights, stats = dependencies.stats_action.call

      json({stats: stats, lights: lights.map(&:as_json)})
    end

    post "/unlock" do
      dependencies.unlock_action.call(params)

      redirect to("/")
    end

    post "/green" do
      dependencies.green_action.call(params)

      redirect to("/")
    end

    post "/red" do
      dependencies.red_action.call(params)

      redirect to("/")
    end

    post "/green_all" do
      dependencies.green_all_action.call

      redirect to("/")
    end
  end
end
