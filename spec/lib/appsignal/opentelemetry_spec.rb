# frozen_string_literal: true

# The configure/shutdown/started behavior is gated on Ruby 3.1+ (the OTel
# SDK ships fork hooks via Process._fork). On older Rubies these unit
# specs are skipped; the config-level gate is covered in `config_spec`.
if DependencyHelper.opentelemetry_present?
  require "opentelemetry/sdk"
  require "opentelemetry-metrics-sdk"
  require "opentelemetry-logs-sdk"

  describe Appsignal::OpenTelemetry do
    let(:config) do
      build_config(
        :options => {
          :name => "collector-mode-spec",
          :push_api_key => "abc",
          :collector_endpoint => "http://127.0.0.1:9090"
        }
      )
    end

    before { described_class.reset! }
    after { described_class.reset! }

    # Attach a root span to the current OTel context, run the block, and detach
    # it afterwards. Stands in for Bug A leaving a previous request's root span
    # attached to the fiber, so the extraction specs can assert that a request
    # with no incoming trace context does not inherit it.
    def with_leaked_ambient_context
      tracer = ::OpenTelemetry.tracer_provider.tracer("leak-spec")
      leaked = tracer.start_root_span("leaked-from-previous-request")
      token = ::OpenTelemetry::Context.attach(
        ::OpenTelemetry::Trace.context_with_span(leaked)
      )
      yield leaked
    ensure
      ::OpenTelemetry::Context.detach(token)
    end

    describe ".configure" do
      context "on success" do
        it "sets started? to true" do
          described_class.configure(config)

          expect(described_class.started?).to be(true)
        end

        it "installs meter and logger providers on the global ::OpenTelemetry" do
          described_class.configure(config)

          expect(::OpenTelemetry.meter_provider)
            .to be_a(::OpenTelemetry::SDK::Metrics::MeterProvider)
          expect(::OpenTelemetry.logger_provider)
            .to be_a(::OpenTelemetry::SDK::Logs::LoggerProvider)
        end

        it "uses the same merged resource (AppSignal + SDK defaults) for all providers" do
          described_class.configure(config)

          tracer_attrs = resource_attrs(::OpenTelemetry.tracer_provider.resource)
          meter_attrs = resource_attrs(::OpenTelemetry.meter_provider.resource)
          # LoggerProvider doesn't expose a public `resource` accessor; read
          # the instance variable directly. Switch to a public method if/when
          # the OTel logs SDK exposes one.
          logger_attrs = resource_attrs(
            ::OpenTelemetry.logger_provider.instance_variable_get(:@resource)
          )

          expect(tracer_attrs).to eq(meter_attrs)
          expect(tracer_attrs).to eq(logger_attrs)

          # AppSignal attrs are present.
          expect(meter_attrs["appsignal.config.name"]).to eq("collector-mode-spec")
          # SDK default attrs survived the merge.
          expect(meter_attrs["telemetry.sdk.name"]).to eq("opentelemetry")
          expect(meter_attrs["telemetry.sdk.language"]).to eq("ruby")
        end
      end

      context "when an SDK gem can't be loaded" do
        let(:err_stream) { std_stream }

        it "logs the error, doesn't raise, and leaves started? false" do
          allow(described_class).to receive(:require)
            .with("opentelemetry/sdk")
            .and_raise(LoadError, "fake load failure")

          logs =
            capture_logs do
              capture_std_streams(std_stream, err_stream) do
                expect { described_class.configure(config) }.not_to raise_error
              end
            end

          expect(described_class.started?).to be(false)
          expect(logs).to include("Cannot configure OpenTelemetry SDK")
          expect(logs).to include("fake load failure")
          expect(err_stream.read).to include("appsignal ERROR")
        end
      end

      context "when SDK setup raises a non-LoadError" do
        let(:err_stream) { std_stream }

        it "logs the error, doesn't raise, and leaves started? false" do
          allow(::OpenTelemetry::SDK).to receive(:configure)
            .and_raise(RuntimeError, "boom")

          logs =
            capture_logs do
              capture_std_streams(std_stream, err_stream) do
                expect { described_class.configure(config) }.not_to raise_error
              end
            end

          expect(described_class.started?).to be(false)
          expect(logs).to include("Error configuring OpenTelemetry SDK")
          expect(logs).to include("boom")
          expect(err_stream.read).to include("appsignal ERROR")
        end
      end

      describe "OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE" do
        before { ENV.delete("OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE") }
        after { ENV.delete("OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE") }

        it "defaults to 'delta' when unset" do
          described_class.configure(config)

          expect(ENV.fetch("OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE"))
            .to eq("delta")
        end

        it "preserves a user-set value" do
          ENV["OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE"] = "cumulative"

          described_class.configure(config)

          expect(ENV.fetch("OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE"))
            .to eq("cumulative")
        end
      end

      describe "endpoint normalization" do
        it "strips trailing slashes before appending the OTLP path" do
          trailing = build_config(
            :options => {
              :name => "collector-mode-spec",
              :push_api_key => "abc",
              :collector_endpoint => "http://127.0.0.1:9090//"
            }
          )
          # Capture the endpoint each OTLP exporter is constructed with so we
          # can prove the slashes were stripped before "/v1/<signal>" was
          # appended. The SDK may construct exporters of its own without
          # passing :endpoint (it falls back to env vars in that case), so we
          # only assert on the endpoints we explicitly pass through.
          endpoints = []
          [
            ::OpenTelemetry::Exporter::OTLP::Exporter,
            ::OpenTelemetry::Exporter::OTLP::Metrics::MetricsExporter,
            ::OpenTelemetry::Exporter::OTLP::Logs::LogsExporter
          ].each do |klass|
            allow(klass).to receive(:new).and_wrap_original do |original, **kwargs|
              endpoints << kwargs[:endpoint] if kwargs[:endpoint]
              original.call(**kwargs)
            end
          end

          described_class.configure(trailing)

          expect(endpoints).to contain_exactly(
            "http://127.0.0.1:9090/v1/traces",
            "http://127.0.0.1:9090/v1/metrics",
            "http://127.0.0.1:9090/v1/logs"
          )
        end
      end

      describe "the certificate authority file" do
        # The exporters take the certificate file as a keyword argument and
        # apply it to their own connection, so all that is left to test here
        # is that AppSignal hands it to them. The proxy has no such argument,
        # which is why that one is tested end to end instead, against a mock
        # proxy in `spec/integration/collector_mode_proxy_spec.rb`.
        it "gives each exporter the file in the ca_file_path option" do
          certificate_files = capture_exporter_option(:certificate_file) do
            with_config(:ca_file_path => "/path/to/cacert.pem") do |ca_config|
              described_class.configure(ca_config)
            end
          end

          expect(certificate_files).to eq(["/path/to/cacert.pem"] * 3)
        end
      end
    end

    # Run the block and return the value each OTLP exporter was built with for
    # `option`, in the order they were built.
    def capture_exporter_option(option)
      values = []
      [
        ::OpenTelemetry::Exporter::OTLP::Exporter,
        ::OpenTelemetry::Exporter::OTLP::Metrics::MetricsExporter,
        ::OpenTelemetry::Exporter::OTLP::Logs::LogsExporter
      ].each do |klass|
        allow(klass).to receive(:new).and_wrap_original do |original, **kwargs|
          values << kwargs[option]
          original.call(**kwargs)
        end
      end

      yield

      values
    end

    def with_config(options)
      yield build_config(
        :options => {
          :name => "collector-mode-spec",
          :push_api_key => "abc",
          :collector_endpoint => "http://127.0.0.1:9090"
        }.merge(options)
      )
    end

    describe ".started?" do
      it "is false before configure has been called" do
        expect(described_class.started?).to be(false)
      end

      it "is true after a successful configure" do
        described_class.configure(config)

        expect(described_class.started?).to be(true)
      end

      it "is reset! back to false on demand" do
        described_class.configure(config)
        described_class.reset!

        expect(described_class.started?).to be(false)
      end
    end

    describe ".shutdown" do
      it "is a no-op when not started" do
        # No SDK is wired up; the API-gem proxy providers raise on shutdown.
        # The guard in shutdown should short-circuit before touching them.
        expect { described_class.shutdown }.not_to raise_error
      end

      it "calls shutdown on all three providers when started" do
        described_class.configure(config)

        expect(::OpenTelemetry.tracer_provider).to receive(:shutdown)
        expect(::OpenTelemetry.meter_provider).to receive(:shutdown)
        expect(::OpenTelemetry.logger_provider).to receive(:shutdown)

        described_class.shutdown
      end

      it "logs and swallows errors raised by a provider's shutdown" do
        described_class.configure(config)

        allow(::OpenTelemetry.meter_provider).to receive(:shutdown)
          .and_raise(RuntimeError, "meter shutdown failed")

        logs = capture_logs { expect { described_class.shutdown }.not_to raise_error }

        expect(logs).to include("Error shutting down OpenTelemetry SDK")
        expect(logs).to include("meter shutdown failed")
      end
    end

    describe ".extract_rack_context" do
      let(:env) do
        { "HTTP_TRACEPARENT" => "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01" }
      end

      it "returns nil when the SDK has not booted" do
        expect(described_class.started?).to be(false)
        expect(described_class.extract_rack_context(env)).to be_nil
      end

      it "extracts from the env with the Rack getter, onto an empty context, when started" do
        require "opentelemetry-common"
        allow(described_class).to receive(:started?).and_return(true)

        received = {}
        allow(::OpenTelemetry.propagation).to receive(:extract) do |carrier, **kwargs|
          received = kwargs.merge(:carrier => carrier)
          ::OpenTelemetry::Context.empty
        end

        described_class.extract_rack_context(env)

        expect(received[:carrier]).to eq(env)
        expect(received[:getter])
          .to eq(::OpenTelemetry::Common::Propagation.rack_env_getter)
        # The base context must carry no ambient span, so a request with no
        # `traceparent` in the carrier does not inherit whatever span happens
        # to be current on the fiber.
        expect(::OpenTelemetry::Trace.current_span(received[:context]))
          .to eq(::OpenTelemetry::Trace::Span::INVALID)
      end

      # Regression for issue #7. With a span already attached to the fiber's
      # context, extraction must reflect only the carrier. Otherwise a request
      # with no `traceparent` inherits the ambient span and its trace merges
      # into the leaked one.
      context "with a span already attached to the current context", :collector_mode do
        before { start_collector_agent }

        it "does not inherit the ambient span when the env has no trace context" do
          with_leaked_ambient_context do |leaked|
            context = described_class.extract_rack_context({})
            extracted = ::OpenTelemetry::Trace.current_span(context).context
            expect(extracted).to_not be_valid
            expect(extracted.hex_trace_id).to_not eq(leaked.context.hex_trace_id)
          end
        end

        it "still continues a real incoming traceparent" do
          with_leaked_ambient_context do
            context = described_class.extract_rack_context(env)
            extracted = ::OpenTelemetry::Trace.current_span(context).context
            expect(extracted.hex_trace_id).to eq("0af7651916cd43dd8448eb211c80319c")
          end
        end
      end
    end

    describe ".extract_job_context" do
      let(:carrier) do
        { "traceparent" => "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01" }
      end

      it "returns nil when the SDK has not booted" do
        expect(described_class.started?).to be(false)
        expect(described_class.extract_job_context({})).to be_nil
      end

      # Regression for issue #7, mirroring the Rack case for the job carrier.
      context "with a span already attached to the current context", :collector_mode do
        before { start_collector_agent }

        it "does not inherit the ambient span when the job has no trace context" do
          with_leaked_ambient_context do |leaked|
            context = described_class.extract_job_context({})
            extracted = ::OpenTelemetry::Trace.current_span(context).context
            expect(extracted).to_not be_valid
            expect(extracted.hex_trace_id).to_not eq(leaked.context.hex_trace_id)
          end
        end

        it "still reads a real incoming traceparent" do
          with_leaked_ambient_context do
            context = described_class.extract_job_context(carrier)
            extracted = ::OpenTelemetry::Trace.current_span(context).context
            expect(extracted.hex_trace_id).to eq("0af7651916cd43dd8448eb211c80319c")
          end
        end
      end
    end

    describe ".if_started" do
      it "does not run the block and returns nil when the SDK has not booted" do
        expect(described_class.started?).to be(false)

        ran = false
        result = described_class.if_started { ran = true }

        expect(ran).to be(false)
        expect(result).to be_nil
      end

      it "runs the block and returns its result when started" do
        allow(described_class).to receive(:started?).and_return(true)

        expect(described_class.if_started { :value }).to eq(:value)
      end
    end

    describe ".build_resource" do
      it "maps AppSignal config attributes onto the resource" do
        resource = described_class.build_resource(
          build_config(
            :root_path => "/path/to/app",
            :options => {
              :name => "my-app",
              :push_api_key => "abc",
              :revision => "deadbeef",
              :hostname => "host-1",
              :service_name => "my-service",
              :filter_attributes => ["password"],
              :ignore_actions => ["IgnoredController#action"],
              :ignore_logs => ["^Started GET"],
              :platform => "heroku"
            }
          )
        )
        attrs = resource_attrs(resource)

        expect(attrs["appsignal.config.name"]).to eq("my-app")
        expect(attrs["appsignal.config.push_api_key"]).to eq("abc")
        expect(attrs["appsignal.config.revision"]).to eq("deadbeef")
        expect(attrs["appsignal.config.app_path"]).to eq("/path/to/app")
        expect(attrs["appsignal.config.platform"]).to eq("heroku")
        expect(attrs["appsignal.config.language_integration"]).to eq("ruby")
        expect(attrs["service.name"]).to eq("my-service")
        expect(attrs["host.name"]).to eq("host-1")
        expect(attrs["appsignal.config.filter_attributes"]).to eq(["password"])
        expect(attrs["appsignal.config.ignore_actions"])
          .to eq(["IgnoredController#action"])
        expect(attrs["appsignal.config.ignore_logs"]).to eq(["^Started GET"])
      end

      it "falls back to defaults for empty revision, service_name, and hostname" do
        # Other specs in the suite set `ENV["APP_REVISION"]` without clearing
        # it (the spec_helper before-block only resets APPSIGNAL_* and
        # _APPSIGNAL_* prefixed vars). Clear it locally so this test is
        # robust to spec ordering.
        ENV.delete("APP_REVISION")

        resource = described_class.build_resource(
          build_config(
            :options => {
              :name => "my-app",
              :push_api_key => "abc",
              :revision => nil,
              :service_name => nil,
              :hostname => nil
            }
          )
        )
        attrs = resource_attrs(resource)

        expect(attrs["appsignal.config.revision"]).to eq("unknown")
        expect(attrs["service.name"]).to eq("app")
        expect(attrs["host.name"]).to eq("unknown")
      end

      [nil, ""].each do |root_path|
        it "omits the app path when the root path is #{root_path.inspect}" do
          resource = described_class.build_resource(
            build_config(
              :root_path => root_path,
              :options => {
                :name => "my-app",
                :push_api_key => "abc"
              }
            )
          )

          expect(resource_attrs(resource)).not_to have_key("appsignal.config.app_path")
        end
      end

      it "omits attributes whose underlying option is nil or empty" do
        resource = described_class.build_resource(
          build_config(
            :options => {
              :name => "my-app",
              :push_api_key => "abc"
            }
          )
        )
        attrs = resource_attrs(resource)

        # These all default to nil or [] and should be dropped so the
        # collector can apply its own defaults.
        %w[
          appsignal.config.filter_function_parameters
          appsignal.config.filter_request_query_parameters
          appsignal.config.ignore_errors
          appsignal.config.ignore_logs
          appsignal.config.platform
          appsignal.config.response_headers
          appsignal.config.send_function_parameters
          appsignal.config.send_request_query_parameters
          appsignal.config.send_request_payload
        ].each do |key|
          expect(attrs).not_to have_key(key)
        end
      end
    end

    # Pull the attributes out of an OTel Resource as a plain hash so specs
    # can assert on them without touching the SDK's internals.
    def resource_attrs(resource)
      resource.attribute_enumerator.to_h
    end
  end
end

# The version gate compares installed gem versions against `REQUIRED_GEMS`.
# These specs stub `Gem.loaded_specs`, so they need no OpenTelemetry gems
# installed and run outside the `opentelemetry_present?` guard above.
describe Appsignal::OpenTelemetry, "collector-mode gem version gate" do
  before { described_class.reset! }
  after { described_class.reset! }

  # Stand in for the installed gems using a `{ name => version }` map. Any gem
  # not in the map is treated as not installed.
  def stub_loaded_specs(versions)
    specs = versions.transform_values do |version|
      instance_double(Gem::Specification, :version => Gem::Version.new(version))
    end
    allow(Gem).to receive(:loaded_specs).and_return(specs)
  end

  # Capture the message passed to the warning logger by the gate.
  def captured_warning
    message = nil
    allow(Appsignal::Utils::StdoutAndLoggerMessage)
      .to receive(:warning) { |msg| message = msg }
    expect(described_class.send(:required_gem_versions_met?)).to be(false)
    message
  end

  context "when every required gem is missing" do
    before { stub_loaded_specs({}) }

    it "warns with only the appsignal-opentelemetry recommendation" do
      message = captured_warning

      expect(message).to include("Add the `appsignal-opentelemetry` gem")
      expect(message).to_not include("not compatible")
      expect(message).to_not include("- opentelemetry")
    end
  end

  context "when an installed gem is older than the supported version" do
    before { stub_loaded_specs("opentelemetry-common" => "0.19.0") }

    it "warns with the recommendation and a line for that gem" do
      message = captured_warning

      expect(message).to include("Add the `appsignal-opentelemetry` gem")
      expect(message).to include("not compatible")
      expect(message).to include("- opentelemetry-common 0.19.0 (requires ~> 0.23)")
    end
  end

  context "when an installed gem is newer than the supported version" do
    before { stub_loaded_specs("opentelemetry-common" => "1.0.0") }

    it "flags the too-new gem as incompatible" do
      message = captured_warning

      expect(message).to include("- opentelemetry-common 1.0.0 (requires ~> 0.23)")
    end
  end
end
