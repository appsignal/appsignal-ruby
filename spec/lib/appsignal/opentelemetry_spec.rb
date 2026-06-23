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

      it "extracts from the env with the Rack getter when started" do
        require "opentelemetry-common"
        allow(described_class).to receive(:started?).and_return(true)

        expect(::OpenTelemetry.propagation).to receive(:extract)
          .with(env, :getter => ::OpenTelemetry::Common::Propagation.rack_env_getter)

        described_class.extract_rack_context(env)
      end
    end

    describe ".build_resource" do
      it "maps AppSignal config attributes onto the resource" do
        resource = described_class.build_resource(
          build_config(
            :options => {
              :name => "my-app",
              :push_api_key => "abc",
              :revision => "deadbeef",
              :hostname => "host-1",
              :service_name => "my-service",
              :filter_attributes => ["password"],
              :ignore_actions => ["IgnoredController#action"]
            }
          )
        )
        attrs = resource_attrs(resource)

        expect(attrs["appsignal.config.name"]).to eq("my-app")
        expect(attrs["appsignal.config.push_api_key"]).to eq("abc")
        expect(attrs["appsignal.config.revision"]).to eq("deadbeef")
        expect(attrs["appsignal.config.language_integration"]).to eq("ruby")
        expect(attrs["service.name"]).to eq("my-service")
        expect(attrs["host.name"]).to eq("host-1")
        expect(attrs["appsignal.config.filter_attributes"]).to eq(["password"])
        expect(attrs["appsignal.config.ignore_actions"])
          .to eq(["IgnoredController#action"])
      end

      it "falls back to 'unknown' for empty revision, service_name, and hostname" do
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
        expect(attrs["service.name"]).to eq("unknown")
        expect(attrs["host.name"]).to eq("unknown")
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
