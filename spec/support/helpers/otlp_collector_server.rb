# frozen_string_literal: true

require "socket"
require "stringio"
require "timeout"
require "zlib"

# A mock OTLP/HTTP collector used by the collector-mode integration spec.
#
# Accepts POSTs to `/v1/traces`, `/v1/metrics` and `/v1/logs` and stores the
# raw protobuf-encoded request body in a per-path Queue. Tests call
# `OTLPCollectorServer.listen_to("/v1/traces")` to block until a request
# arrives and then decode it with the proto stubs that ship inside the
# `opentelemetry-exporter-otlp` gem.
#
# Hand-rolled on top of `TCPServer` rather than Sinatra/WEBrick so the spec
# suite doesn't drag those gems into every framework gemfile via the gemspec.
module OTLPCollectorServer
  PATHS = %w[/v1/traces /v1/metrics /v1/logs].freeze

  @received = Hash.new { |h, k| h[k] = Queue.new }
  @booted = false
  @port = nil

  class << self
    attr_reader :received

    # The port the mock server is bound to. Assigned by `boot!`, which binds to
    # an OS-assigned free port rather than a fixed one, so concurrent suite runs
    # on the same machine don't collide. `nil` until booted.
    attr_reader :port

    def endpoint
      "http://127.0.0.1:#{port}"
    end

    # Env vars that put a spawned runner into collector mode, pointed at this
    # mock server. Returns a plain Hash so callers can merge in other env
    # vars, e.g. `OTLPCollectorServer.env.merge("OTEL_..." => "...")`.
    def env
      { "APPSIGNAL_COLLECTOR_ENDPOINT" => endpoint }
    end

    def listen_to(path, timeout: 10)
      Timeout.timeout(timeout) { received[path].pop }
    rescue Timeout::Error
      raise "Timed out after #{timeout}s waiting for OTLP request to #{path}. " \
        "Other received paths so far: " \
        "#{received.transform_values(&:size).reject { |_, s| s.zero? }.inspect}"
    end

    def clear
      received.each_value(&:clear)
    end

    def boot!
      return if @booted

      # Port 0 lets the OS pick a free port; read the assigned one back so
      # `endpoint`/`env` can hand it to the spawned runners.
      @server = TCPServer.new("127.0.0.1", 0)
      @port = @server.addr[1]
      @booted = true
      @thread = Thread.new do
        Thread.current.abort_on_exception = false
        accept_loop
      end
    end

    private

    def accept_loop
      loop do
        client = @server.accept
        Thread.new(client) { |c| handle(c) }
      end
    rescue IOError, Errno::EBADF
      # Server socket was closed; exit the loop.
    end

    def handle(client)
      request_line = client.gets
      return unless request_line

      method, path, _ = request_line.strip.split(" ", 3)
      headers = read_headers(client)

      length = headers["content-length"].to_i
      raw_body = length.positive? ? client.read(length) : ""
      body =
        if headers["content-encoding"] == "gzip"
          Zlib::GzipReader.new(StringIO.new(raw_body)).read
        else
          raw_body
        end

      if method == "POST" && PATHS.include?(path)
        received[path] << { :headers => rack_style_headers(headers), :body => body }
        write_response(client, 200, "application/x-protobuf", "")
      else
        write_response(client, 404, "text/plain", "")
      end
    rescue StandardError
      # Swallow per-connection errors so a malformed request doesn't bring
      # down the accept loop for the rest of the suite.
    ensure
      begin
        client&.close
      rescue StandardError
        # ignore
      end
    end

    def read_headers(client)
      headers = {}
      while (line = client.gets) && line != "\r\n"
        key, _, value = line.strip.partition(":")
        headers[key.downcase] = value.strip
      end
      headers
    end

    # Mimic the rack env header keys the previous Sinatra-based server
    # exposed so any future spec that introspects `:headers` finds the
    # same shape.
    def rack_style_headers(headers)
      headers.each_with_object({}) do |(k, v), h|
        env_key =
          if k == "content-type"
            "CONTENT_TYPE"
          else
            "HTTP_#{k.upcase.tr("-", "_")}"
          end
        h[env_key] = v
      end
    end

    def write_response(client, status, content_type, body)
      reason = status == 200 ? "OK" : "Not Found"
      client.write("HTTP/1.1 #{status} #{reason}\r\n")
      client.write("Content-Type: #{content_type}\r\n")
      client.write("Content-Length: #{body.bytesize}\r\n")
      client.write("Connection: close\r\n")
      client.write("\r\n")
      client.write(body)
    end
  end
end
