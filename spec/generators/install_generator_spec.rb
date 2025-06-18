# frozen_string_literal: true

require "spec_helper"
require "generators/stoplight/install/install_generator"
require "debug"

RSpec.describe Stoplight::Generators::InstallGenerator, type: :generator do
  destination File.expand_path("../../tmp", __dir__)

  let(:args) { [] }

  before do
    prepare_destination
  end

  describe "initializer" do
    subject { file(initializer_path) }

    let(:initializer_path) { "config/initializers/stoplight.rb" }

    before do
      if File.exist?(File.join(destination_root, initializer_path))
        FileUtils.rm(File.join(destination_root, initializer_path))
      end
    end

    it "creates initializer with Redis configuration" do
      run_generator(args)

      is_expected.to be_a_file
      is_expected.to have_correct_syntax
      is_expected.to contain(/Stoplight.configure do \|config\|/)
      is_expected.to contain(/require "redis"/)
      is_expected.to contain(/redis = Redis.new/)
      is_expected.to contain(/data_store = Stoplight::DataStore::Redis.new/)
      is_expected.to contain(/Stoplight.configure do |config|/)
      is_expected.to contain(/config.data_store = data_store/)
    end
  end

  describe "admin panel" do
    subject { file("config/routes.rb") }

    let(:config_path) { File.join(destination_root, "config") }
    let(:routes_path) { File.join(destination_root, "config", "routes.rb") }
    let(:gemfile_path) { File.join(destination_root, "Gemfile") }

    before do
      FileUtils.mkdir_p(config_path)
      FileUtils.touch(gemfile_path)
      File.write(routes_path, <<~RUBY
        Rails.application.routes.draw do
        end
      RUBY
      )
    end

    after { FileUtils.rm(routes_path) }

    context "without admin panel flag" do
      it "does not mount admin panel to routes" do
        run_generator(args)

        is_expected.not_to contain(/mount Stoplight::Admin/)
      end

      context "dependencies" do
        subject { file("Gemfile") }

        it "does not add dependencies to Gemfile" do
          is_expected.to_not contain(/gem 'redis'/)
          is_expected.to_not contain(/gem 'sinatra', require: false/)
          is_expected.to_not contain(/gem 'sinatra-contrib', require: false/)
        end
      end
    end

    context "with admin panel flag" do
      let(:args) { ["--with-admin-panel"] }

      it "mounts admin panel to routes" do
        run_generator(args)

        is_expected.to have_correct_syntax
        is_expected.to contain(/mount Stoplight::Admin => '\/stoplights'/)
        is_expected.to contain(/Stoplight::Admin.use(Rack::Auth::Basic) do |username, password|/)
        is_expected.to contain(/username == ENV\["STOPLIGHT_ADMIN_USERNAME"\] && password == ENV\["STOPLIGHT_ADMIN_PASSWORD"\]/)
      end

      context "dependencies" do
        subject { file("Gemfile") }

        it "adds dependencies to Gemfile" do
          run_generator(args)

          is_expected.to contain(/gem 'redis'/)
          is_expected.to contain(/gem 'sinatra', require: false/)
          is_expected.to contain(/gem 'sinatra-contrib', require: false/)
        end
      end
    end
  end
end
