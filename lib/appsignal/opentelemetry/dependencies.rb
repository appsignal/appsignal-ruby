# frozen_string_literal: true

module Appsignal
  module OpenTelemetry
    # @!visibility private
    #
    # The OpenTelemetry gems collector mode depends on, mapped to the minimum
    # version we support. These gems are *not* declared in the gemspec: they
    # are optional and only required when collector mode is active. Apps that
    # opt into collector mode install them into their own bundle (see the
    # collector documentation).
    #
    # The floors are the first releases that support Ruby 3.1 (the family-wide
    # "3.1 min version" train), except `opentelemetry-metrics-sdk`, which is
    # floored at the release that added `Process._fork`-based fork recovery for
    # the periodic metric reader. That fork support is why collector mode
    # itself requires Ruby 3.1 (see `MIN_RUBY_VERSION_FOR_COLLECTOR_MODE` in
    # `Appsignal::Config`).
    #
    # This file must stay free of any other dependency so it can be required
    # directly from a Gemfile (see `gemfiles/collector.rb`) and from the
    # runtime version gate in `Appsignal::OpenTelemetry.configure` without
    # loading the rest of the gem.
    REQUIRED_GEMS = {
      "opentelemetry-sdk" => "1.8.0",
      "opentelemetry-metrics-sdk" => "0.7.1",
      "opentelemetry-logs-sdk" => "0.2.0",
      "opentelemetry-exporter-otlp" => "0.30.0",
      "opentelemetry-exporter-otlp-metrics" => "0.4.0",
      "opentelemetry-exporter-otlp-logs" => "0.2.0"
    }.freeze
  end
end
