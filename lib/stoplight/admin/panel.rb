# frozen_string_literal: true

module Stoplight
  class Admin
    # The redesigned admin panel, mountable next to or instead of +Stoplight::Admin+. It shows the
    # systems configured on +Stoplight::Admin+, so a host configures once and mounts either app.
    #
    # @example Mounting in Rails
    #   Stoplight::Admin.configure do |config|
    #     config.add_system Payments
    #   end
    #
    #   mount Stoplight::Admin::Panel => "/stoplights"
    #
    class Panel < Sinatra::Base
      helpers Helpers

      set :systems, proc { Admin.settings.systems }
      set :erb, escape_html: true
      set :views, File.join(T.must(__dir__), "panel", "views")
      set :nonce, proc { |request| }
      set :public_folder, ASSETS_PATH
      set :static_cache_control, [:public, max_age: ONE_YEAR_IN_SECONDS, immutable: true]

      get "/" do
        system = settings.systems.first

        redirect system_url(system.config.id, "/lights")
      end
    end
  end
end
