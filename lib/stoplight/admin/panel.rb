# frozen_string_literal: true

module Stoplight
  class Admin
    # A Sinatra dashboard listing every light of a configured system and its state.
    #
    # It reads its systems and its +read_only+ setting from +Stoplight::Admin+, so a host
    # configures them there and mounts either app.
    #
    # @example Mounting in Rails
    #   Payments = Stoplight.register_system("Payments", data_store:)
    #
    #   Stoplight::Admin.configure do |config|
    #     config.add_system Payments
    #   end
    #
    #   mount Stoplight::Admin::Panel => "/stoplights"
    #
    class Panel < Sinatra::Base
      helpers Helpers

      set :systems, proc { Admin.settings.systems }
      set :read_only, proc { Admin.settings.read_only? }
      set :views, File.join(T.must(__dir__), "panel", "views")
      set :nonce, proc { |request| }
      set :public_folder, ASSETS_PATH
      set :static_cache_control, [:public, max_age: ONE_YEAR_IN_SECONDS, immutable: true]

      before do
        if settings.read_only? && !request.get? && !request.head?
          halt 403, "Stoplight Admin is running in read-only mode."
        end
      end

      get "/" do
        system = settings.systems.first

        redirect system_url(system.config.id, "/lights")
      end

      get "/systems/:system_id/lights" do
        lights = dependencies.light_list_action.call

        erb :lights, layout: !turbo_frame_request?, locals: {lights: lights, selected_light: selected_light(lights)}
      end

      get "/systems/:system_id/lights/:light_id" do
        lights = dependencies.light_list_action.call

        erb :lights, layout: !turbo_frame_request?, locals: {lights: lights, selected_light: find_light(lights, params[:light_id])}
      end
    end
  end
end
