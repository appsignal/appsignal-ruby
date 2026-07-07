# frozen_string_literal: true

# Gemfile fragment that adds the optional OpenTelemetry gems collector mode
# needs. `eval_gemfile`'d by the `*-collector.gemfile` variants on top of their
# base gemfile. The versions come from the single source of truth shared with
# the runtime version gate.
require_relative "../lib/appsignal/opentelemetry/dependencies"

Appsignal::OpenTelemetry::REQUIRED_GEMS.each do |name, minimum_version|
  gem name, ">= #{minimum_version}"
end
