require "rack/mock"

module Appsignal
  class Demo
    class TestError < StandardError; end

    class << self
      def transmit
        Appsignal.start
        Appsignal.start_logger
        return false unless Appsignal.active?

        create_example_error_request
        create_example_performance_request
        true
      end

      private

      def create_example_error_request
        transaction = Appsignal::Transaction.create(
          SecureRandom.uuid,
          Appsignal::Transaction::HTTP_REQUEST,
          rack_request
        )
        begin
          raise TestError,
            "Hello world! This is an error used for demonstration purposes."
        rescue => error
          Appsignal.set_error(error)
        end
        transaction.set_http_or_background_queue_start
        transaction.set_metadata("path", "/hello")
        transaction.set_metadata("method", "GET")
        transaction.set_action("DemoController#hello")
        add_demo_metadata_to transaction
        Appsignal::Transaction.complete_current!
      end

      def create_example_performance_request
        transaction = Appsignal::Transaction.create(
          SecureRandom.uuid,
          Appsignal::Transaction::HTTP_REQUEST,
          rack_request
        )
        Appsignal.instrument "action_view.render", "Render hello.html.erb", "<h1>Hello world!</h1>" do
          sleep 2
        end
        transaction.set_http_or_background_queue_start
        transaction.set_metadata("path", "/hello")
        transaction.set_metadata("method", "GET")
        transaction.set_action("DemoController#hello")
        add_demo_metadata_to transaction
        Appsignal::Transaction.complete_current!
      end

      def add_demo_metadata_to(transaction)
        transaction.set_metadata("demo_sample", "true")
      end

      def rack_request
        env = ::Rack::MockRequest.env_for(
          "/demo",
          :params => {
            "controller" => "demo",
            "action" => "hello"
          },
          "REMOTE_ADDR" => "127.0.0.1",
          "REQUEST_METHOD" => "GET",
          "SERVER_NAME" => "localhost",
          "SERVER_PORT" => "80",
          "SERVER_PROTOCOL" => "HTTP/1.1",
          "REQUEST_URI" => "/hello",
          "PATH_INFO" => "/hello",
          "HTTP_ACCEPT" => "text/html,application/xhtml+xml",
          "HTTP_ACCEPT_ENCODING" => "gzip, deflate, sdch",
          "HTTP_ACCEPT_LANGUAGE" => "en-US,en;q=0.8,nl;q=0.6",
          "HTTP_CACHE_CONTROL" => "max-age=0",
          "HTTP_CONNECTION" => "keep-alive",
          "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_0)",
          "HTTP_REFERER" => "http://appsignal.com/accounts"
        )
        ::Rack::Request.new(env)
      end
    end
  end
end
