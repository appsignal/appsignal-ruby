# frozen_string_literal: true

if defined?(Appsignal)
  Appsignal::Environment.report_enabled("object_instrumentation")
end

if RUBY_VERSION < "2.0"
  require "appsignal/integrations/object_ruby_19"
else
  require "appsignal/integrations/object_ruby_modern"
end
