# frozen_string_literal: true

require "socket"
require "timeout"

# A mock HTTP proxy used by the collector-mode proxy integration spec.
#
# It records the request line and the proxy authorization of everything sent
# to it, and answers each request with an empty 200. It never forwards
# anything on: the spec asserts on what reached the proxy, and on the mock
# collector having received nothing as a result.
#
# A request sent through a proxy carries the whole URL in its request line,
# where one sent straight to the server carries only the path. That is what
# tells the two apart.
#
# Hand-rolled on top of `TCPServer` for the same reason as
# {OTLPCollectorServer}: so the spec suite doesn't drag a web server gem into
# every framework gemfile.
module HTTPProxyServer
  @received = Queue.new
  @booted = false
  @port = nil

  class << self
    # The port the mock proxy is bound to. Assigned by `boot!`, which binds to
    # an OS-assigned free port rather than a fixed one, so concurrent suite
    # runs on the same machine don't collide. `nil` until booted.
    attr_reader :port

    def address
      "http://127.0.0.1:#{port}"
    end

    # Env vars that point a spawned runner's AppSignal config at this mock
    # proxy. Returns a plain Hash so callers can merge in other env vars.
    def env
      { "APPSIGNAL_HTTP_PROXY" => address }
    end

    # Pop one received request, waiting for it to arrive. Returns a Hash with
    # `:line` and `:authorization`.
    def listen(timeout: 10)
      Timeout.timeout(timeout) { @received.pop }
    rescue Timeout::Error
      raise "Timed out after #{timeout}s waiting for a request to the proxy."
    end

    def received_count
      @received.size
    end

    def clear
      @received.clear
    end

    def boot!
      return if @booted

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

      headers = read_headers(client)
      length = headers["content-length"].to_i
      # Read the body, so the client is not left writing to a socket that
      # closed before it finished.
      client.read(length) if length.positive?

      @received << {
        :line => request_line.strip,
        :authorization => headers["proxy-authorization"]
      }

      write_response(client)
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

    def write_response(client)
      client.write("HTTP/1.1 200 OK\r\n")
      client.write("Content-Type: application/x-protobuf\r\n")
      client.write("Content-Length: 0\r\n")
      client.write("Connection: close\r\n")
      client.write("\r\n")
    end
  end
end
