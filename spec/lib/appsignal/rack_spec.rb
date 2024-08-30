describe Appsignal::Rack::Utils do
  describe ".queue_start_from" do
    let(:header_time) { fixed_time - 0.4 }
    let(:header_time_value) { (header_time * factor).to_i }
    subject { described_class.queue_start_from(env) }

    shared_examples "HTTP queue start" do
      context "when env is nil" do
        let(:env) { nil }

        it { is_expected.to be_nil }
      end

      context "with no relevant header set" do
        let(:env) { {} }

        it { is_expected.to be_nil }
      end

      context "with the HTTP_X_REQUEST_START header set" do
        let(:env) { { "HTTP_X_REQUEST_START" => "t=#{header_time_value}" } }

        it { is_expected.to eq 1_389_783_599_600 }

        context "with unparsable content" do
          let(:env) { { "HTTP_X_REQUEST_START" => "something" } }

          it { is_expected.to be_nil }
        end

        context "with unparsable content at the end" do
          let(:env) { { "HTTP_X_REQUEST_START" => "t=#{header_time_value}aaaa" } }

          it { is_expected.to eq 1_389_783_599_600 }
        end

        context "with a really low number" do
          let(:env) { { "HTTP_X_REQUEST_START" => "t=100" } }

          it { is_expected.to be_nil }
        end

        context "with the alternate HTTP_X_QUEUE_START header set" do
          let(:env) { { "HTTP_X_QUEUE_START" => "t=#{header_time_value}" } }

          it { is_expected.to eq 1_389_783_599_600 }
        end
      end
    end

    context "time in milliseconds" do
      let(:factor) { 1_000 }

      it_should_behave_like "HTTP queue start"
    end

    context "time in microseconds" do
      let(:factor) { 1_000_000 }

      it_should_behave_like "HTTP queue start"
    end
  end
end

describe Appsignal::Rack::ApplyRackRequest do
  describe "#apply_to" do
    let(:merged_env) do
      Rack::MockRequest.env_for(
        "/some/path",
        {
          "REQUEST_METHOD" => "GET",
          :params => { "page" => 2, "query" => "lorem" },
          "rack.session" => { "session" => "data", "user_id" => 123 }
        }.merge(env)
      )
    end
    let(:env) { {} }
    let(:request) { ::Rack::Request.new(merged_env) }
    let(:options) { {} }
    let(:helper) { described_class.new(request, options) }
    let(:transaction) { http_request_transaction }
    before { start_agent }

    def apply_to(transaction)
      helper.apply_to(transaction)
      transaction._sample
    end

    it "sets request metadata" do
      apply_to(transaction)

      expect(transaction).to include_metadata(
        "method" => "GET",
        "path" => "/some/path"
      )
      expect(transaction).to include_environment(
        "REQUEST_METHOD" => "GET",
        "PATH_INFO" => "/some/path"
        # and more, but we don't need to test Rack mock defaults
      )
    end

    context "with an invalid HTTP request method" do
      let(:env) { { "REQUEST_METHOD" => "FOO" } }

      it "stores the invalid HTTP request method" do
        apply_to(transaction)

        expect(transaction).to include_metadata("method" => "FOO")
      end
    end

    context "when fetching the request method raises an error" do
      class BrokenRequestMethodRequest < Rack::Request
        def request_method
          raise "uh oh!"
        end
      end

      let(:env) { { "REQUEST_METHOD" => "FOO" } }
      let(:request) { BrokenRequestMethodRequest.new(merged_env) }

      it "does not store the invalid HTTP request method" do
        logs = capture_logs { apply_to(transaction) }

        expect(transaction).to_not include_metadata("method" => anything)
        expect(logs).to contains_log(
          :error,
          "Exception while fetching the HTTP request method: RuntimeError: uh oh"
        )
      end
    end

    it "sets request parameters" do
      apply_to(transaction)

      expect(transaction).to include_params(
        "page" => "2",
        "query" => "lorem"
      )
    end

    context "when fetching the request method raises an error" do
      class BrokenRequestParamsRequest < Rack::Request
        def params
          raise "uh oh!"
        end
      end

      let(:request) { BrokenRequestParamsRequest.new(merged_env) }
      let(:options) { { :params_method => :params } }

      it "does not store the invalid HTTP request method" do
        logs = capture_logs { apply_to(transaction) }

        expect(transaction).to_not include_params
        expect(logs).to contains_log(
          :error,
          "Exception while fetching params " \
            "from 'BrokenRequestParamsRequest#params': RuntimeError uh oh!"
        )
      end
    end

    it "sets session data" do
      apply_to(transaction)

      expect(transaction).to include_session_data("session" => "data", "user_id" => 123)
    end

    context "with Hash-like session data" do
      let(:env) { { "rack.session" => HashLike.new("hash-like" => "value", "user_id" => 123) } }

      it "sets session data" do
        apply_to(transaction)

        expect(transaction).to include_session_data("hash-like" => "value", "user_id" => 123)
      end
    end

    context "with queue start header" do
      let(:queue_start_time) { fixed_time * 1_000 }
      let(:env) { { "HTTP_X_REQUEST_START" => "t=#{queue_start_time.to_i}" } } # in milliseconds

      it "sets the queue start" do
        apply_to(transaction)

        expect(transaction).to have_queue_start(queue_start_time)
      end
    end

    class RackFilteredRequest
      attr_reader :env

      def initialize(env)
        @env = env
      end

      def path
        "/static/path"
      end

      def request_method
        "GET"
      end

      def filtered_params
        { "abc" => "123" }
      end

      def session
        { "data" => "value" }
      end
    end

    context "with overridden request class and params method" do
      let(:request) { RackFilteredRequest.new(env) }
      let(:options) { { :params_method => :filtered_params } }

      it "uses the overridden request class and params method to fetch params" do
        apply_to(transaction)

        expect(transaction).to include_params("abc" => "123")
      end

      it "uses the overridden request class to fetch session data" do
        apply_to(transaction)

        expect(transaction).to include_session_data("data" => "value")
      end
    end
  end
end
