# frozen_string_literal: true

require "spec_helper"
require "generators/stoplight/install/install_generator"

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
    subject { file(routes_path) }

    let(:config_path) { "config" }
    let(:routes_path) { "#{config_path}/routes.rb" }

    before do
      FileUtils.mkdir_p(File.join(destination_root, config_path))
      FileUtils.rm(File.join(destination_root, routes_path)) if File.exist?(File.join(destination_root, routes_path))
      File.write(File.join(destination_root, routes_path), <<~RUBY
        Rails.application.routes.draw do
        end
      RUBY
      )
    end

    context "without admin panel flag" do
      it "does not mount admin panel to routes" do
        run_generator(args)

        is_expected.not_to contain(/mount Stoplight::Admin/)
      end
    end

    context "with admin panel flag" do
      let(:args) { ["--with-admin-panel"] }

      it "mounts admin panel to routes" do
        run_generator(args)

        is_expected.to have_correct_syntax
        is_expected.to contain(/mount Stoplight::Admin => '\/stoplights'/)
      end
    end
  end
end
