#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "yaml"

# Derives the CI matrices from .github/ci-versions.yml and grades a finished run.
# Both are used by .github/workflows/ci.yml and are covered by spec/unit/bin/ci_spec.rb.
module CI
  Error = Class.new(StandardError)

  CONFIG_PATH = File.expand_path("../.github/ci-versions.yml", __dir__)

  class Versions
    # The two supported ways to build a light. Part of the public API, not a version knob,
    # so it lives here rather than in ci-versions.yml.
    LIGHT_CREATIONS = ["Stoplight()", "System#register"].freeze

    def initialize(config)
      @config = config
    end

    def latest_ruby
      config.fetch("latest_ruby")
    end

    # The gating run: the pinned Ruby against the newest image of every engine.
    def smoke
      {"include" => latest_images.map { |image| {"ruby" => latest_ruby, "data-store-image" => image} }}
    end

    # Deliberately overlaps smoke. Subtracting the overlap would couple the two lists so that
    # editing one silently drops coverage from the other, which costs more than the repeated jobs.
    def extended
      {"ruby" => rubies, "data-store-image" => images}
    end

    def features
      redis = latest_images.flat_map do |image|
        LIGHT_CREATIONS.map { |creation| feature_entry("Redis", creation, image) }
      end
      memory = LIGHT_CREATIONS.map { |creation| feature_entry("Memory", creation, latest_images.first) }

      {"include" => redis + memory}
    end

    # Collects every problem before raising so a half-finished version bump is reported in one run.
    def validate!
      problems = []
      problems << "latest_ruby #{latest_ruby} is not in rubies" unless rubies.include?(latest_ruby)
      (latest_images - images).each do |image|
        problems << "latest_images entry #{image} is not in images"
      end

      raise Error, problems.join("\n") unless problems.empty?
    end

    private

    attr_reader :config

    def rubies
      config.fetch("rubies")
    end

    def images
      config.fetch("images")
    end

    def latest_images
      config.fetch("latest_images")
    end

    # The Memory store ignores the image, but a service container is started regardless.
    def feature_entry(store, creation, image)
      {"data-store" => store, "light-creation" => creation, "data-store-image" => image}
    end
  end

  class Results
    def initialize(needs)
      @needs = needs
    end

    # A job skipped because an upstream failed, or because its approval gate never opened, is not a pass.
    def failures
      needs.reject { |_, outcome| outcome["result"] == "success" }
        .map { |name, outcome| "#{name}: #{outcome["result"]}" }
    end

    private

    attr_reader :needs
  end

  module CLI
    module_function

    def run(argv)
      case argv.first
      when "matrices" then matrices
      when "verify" then verify
      else abort("usage: bin/ci {matrices|verify}")
      end
    end

    def matrices
      versions = Versions.new(YAML.load_file(CONFIG_PATH))
      versions.validate!

      write_outputs(
        "latest-ruby" => versions.latest_ruby,
        "smoke" => versions.smoke.to_json,
        "extended" => versions.extended.to_json,
        "features" => versions.features.to_json
      )
    rescue Error => e
      abort(e.message)
    end

    def verify
      results = Results.new(JSON.parse(ENV.fetch("RESULTS")))
      failures = results.failures

      abort("Not every stage succeeded:\n#{failures.join("\n")}") unless failures.empty?
      warn("Every stage succeeded.")
    end

    def write_outputs(outputs)
      outputs.each { |name, value| warn("#{name}=#{value}") }

      File.open(ENV.fetch("GITHUB_OUTPUT"), "a") do |file|
        outputs.each { |name, value| file.puts("#{name}=#{value}") }
      end
    end
  end
end

CI::CLI.run(ARGV) if $PROGRAM_NAME == __FILE__
