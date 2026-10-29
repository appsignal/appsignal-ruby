PROJECT_ROOT = "../../../".freeze
$LOAD_PATH.unshift(File.expand_path("ext", PROJECT_ROOT))
$LOAD_PATH.unshift(File.expand_path("lib", PROJECT_ROOT))

require "appsignal"

# Set by the invalid UTF-8 specs: a String tagged UTF-8 holding a byte that
# is not UTF-8, or a binary String with a byte above 127.
INVALID_STRING =
  case ENV.fetch("INVALID_UTF8_ENCODING", nil)
  when "utf8" then "caf\xE9".dup.force_encoding(Encoding::UTF_8)
  when "binary" then "caf\xE9".b
  end

# The action of the transaction that carries the invalid string, so the spec
# can tell its span apart from the valid transaction's span.
INVALID_ACTION = "InvalidUtf8Controller#index".freeze

def monitor_invalid(namespace: nil, &block)
  Appsignal.monitor(:action => INVALID_ACTION, :namespace => namespace, &block)
end

# Returns an error whose cause has the invalid string as its message.
def error_with_invalid_cause
  begin
    raise ArgumentError, INVALID_STRING
  rescue ArgumentError
    raise StandardError, "outer error"
  end
rescue StandardError => error
  error
end

# Name, environment and push API key come from the env vars the Runner
# injects (see `Runner::DEFAULT_ENV`); `Appsignal.start` loads them.
Appsignal.start

# Exercise the public AppSignal tracing helpers; in collector mode these
# should route through the OpenTelemetry transaction backend and produce
# a root span plus nested event spans reaching the mock collector at
# `/v1/traces`.
Appsignal.monitor(:action => "MyController#index") do
  Appsignal.instrument_sql("active_record.sql", "Find user", "SELECT * FROM users") do
    # No body; the SQL event span itself is what the spec asserts on.
  end
  Appsignal.instrument("template.render") do
    Appsignal.instrument("partial.render") do
      # No body; the nested event span itself is what the spec asserts on.
    end
  end
end

# Set by the invalid UTF-8 specs: puts the invalid string in one place, in a
# transaction exported in the same batch as the valid one above. One place
# per run, so a failing spec names the place that loses data.
case ENV.fetch("INVALID_UTF8_SCENARIO", nil)
when nil
  nil
when "action"
  Appsignal.monitor(:action => INVALID_STRING) do
    # No body; the root span itself is what the spec asserts on.
  end
when "namespace"
  monitor_invalid(:namespace => INVALID_STRING) do
    # No body; the root span itself is what the spec asserts on.
  end
when "metadata"
  monitor_invalid { Appsignal::Transaction.current.set_metadata("path", INVALID_STRING) }
when "tag_value"
  monitor_invalid { Appsignal.add_tags("invalid_tag" => INVALID_STRING) }
when "tag_key"
  monitor_invalid { Appsignal.add_tags(INVALID_STRING => "value") }
when "request_payload"
  monitor_invalid { Appsignal.add_params("invalid_param" => INVALID_STRING) }
when "session_data"
  monitor_invalid { Appsignal.add_session_data("invalid_session" => INVALID_STRING) }
when "custom_data"
  monitor_invalid { Appsignal.add_custom_data("invalid_custom" => INVALID_STRING) }
when "request_header"
  monitor_invalid { Appsignal.add_request_headers("accept" => INVALID_STRING) }
when "opentelemetry_attribute_value"
  monitor_invalid do
    Appsignal::Transaction.current.add_opentelemetry_attributes(
      "invalid.attribute" => INVALID_STRING
    )
  end
when "opentelemetry_attribute_key"
  monitor_invalid do
    Appsignal::Transaction.current.add_opentelemetry_attributes(INVALID_STRING => "value")
  end
when "error_message"
  monitor_invalid { Appsignal.set_error(StandardError.new(INVALID_STRING)) }
when "error_backtrace"
  monitor_invalid do
    error = StandardError.new("error with invalid backtrace")
    error.set_backtrace([INVALID_STRING])
    Appsignal.set_error(error)
  end
when "error_cause_message"
  monitor_invalid { Appsignal.set_error(error_with_invalid_cause) }
when "breadcrumb_message"
  monitor_invalid { Appsignal.add_breadcrumb("category", "action", INVALID_STRING) }
when "breadcrumb_metadata"
  monitor_invalid do
    Appsignal.add_breadcrumb("category", "action", "message", "key" => INVALID_STRING)
  end
when "event_name"
  monitor_invalid do
    Appsignal.instrument(INVALID_STRING) do
      # No body; the event span itself is what the spec asserts on.
    end
  end
when "event_title"
  monitor_invalid do
    Appsignal.instrument("event.invalid", INVALID_STRING) do
      # No body; the event span itself is what the spec asserts on.
    end
  end
when "event_body"
  monitor_invalid do
    Appsignal.instrument("event.invalid", "Title", INVALID_STRING) do
      # No body; the event span itself is what the spec asserts on.
    end
  end
when "sql_body"
  monitor_invalid do
    Appsignal.instrument_sql("sql.invalid", "Query", INVALID_STRING) do
      # No body; the event span itself is what the spec asserts on.
    end
  end
else
  raise "Unknown INVALID_UTF8_SCENARIO: #{ENV.fetch("INVALID_UTF8_SCENARIO")}"
end

# Shut AppSignal down so the OTel providers drain their buffers and the
# spec sees the queued request deterministically.
Appsignal.stop("integration test")

puts "DONE"
