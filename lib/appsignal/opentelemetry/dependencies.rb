# frozen_string_literal: true

module Appsignal
  module OpenTelemetry
    # @!visibility private
    #
    # The OpenTelemetry gems collector mode supports, mapped to their version
    # requirements. Each gem maps to an array of requirement strings so a gem
    # can carry more than one constraint later, even though each holds a single
    # `~>` requirement today. These gems are *not* declared in the gemspec:
    # they are optional and only required when collector mode is active. Apps
    # that opt into collector mode install them into their own bundle (see the
    # collector documentation).
    #
    # Each requirement pins a floor and a ceiling. The floor is the version the
    # minimum supported Ruby (3.1) resolves to in our CI collector matrix. The
    # ceiling is a pessimistic `~>` cap at the next major version. We set the
    # cap loosely on purpose so it does not block customers from updating these
    # gems within a major version.
    #
    # This file must stay free of any other dependency so it can be required
    # directly from a Gemfile (see `gemfiles/collector.rb`) and from the
    # runtime version gate in `Appsignal::OpenTelemetry.configure` without
    # loading the rest of the gem.
    REQUIRED_GEMS = {
      "opentelemetry-sdk" => ["~> 1.10"],
      "opentelemetry-common" => ["~> 0.23"],
      "opentelemetry-metrics-sdk" => ["~> 0.12"],
      "opentelemetry-logs-sdk" => ["~> 0.4"],
      "opentelemetry-exporter-otlp" => ["~> 0.32"],
      "opentelemetry-exporter-otlp-metrics" => ["~> 0.7"],
      "opentelemetry-exporter-otlp-logs" => ["~> 0.3"]
    }.freeze
  end
end
