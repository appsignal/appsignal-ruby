# frozen_string_literal: true

if DependencyHelper.opentelemetry_present?
  require "opentelemetry/sdk"
  require "opentelemetry-metrics-sdk"
  require "opentelemetry-logs-sdk"

  describe Appsignal::OpenTelemetry::ProcessResource do
    let(:config) do
      build_config(
        :options => {
          :name => "process-resource-spec",
          :push_api_key => "abc",
          :collector_endpoint => "http://127.0.0.1:9090"
        }
      )
    end
    let(:uuid_v4) { /\A\h{8}-\h{4}-4\h{3}-\h{4}-\h{12}\z/ }

    around do |example|
      providers = [
        ::OpenTelemetry.tracer_provider,
        ::OpenTelemetry.meter_provider,
        ::OpenTelemetry.logger_provider
      ]
      example.run
    ensure
      ::OpenTelemetry.tracer_provider, ::OpenTelemetry.meter_provider,
        ::OpenTelemetry.logger_provider = providers
    end

    before { Appsignal::OpenTelemetry.reset! }
    after { Appsignal::OpenTelemetry.reset! }

    def attributes(resource)
      resource.attribute_enumerator.to_h
    end

    def provider_attributes
      {
        "tracer" => attributes(::OpenTelemetry.tracer_provider.resource),
        "meter" => attributes(::OpenTelemetry.meter_provider.resource),
        "logger" => attributes(::OpenTelemetry.logger_provider.instance_variable_get(:@resource))
      }
    end

    def fork_in_place
      instance_ids = described_class.before_fork
      allow(Process).to receive(:pid).and_return(Process.pid + 1)
      described_class.after_fork(instance_ids)
    end

    describe ".service_instance_id" do
      it "is a UUIDv4 that stays the same within a process" do
        id = described_class.service_instance_id

        expect(id).to match(uuid_v4)
        expect(described_class.service_instance_id).to eq(id)
      end

      it "changes when the process ID changes" do
        id = described_class.service_instance_id
        allow(Process).to receive(:pid).and_return(Process.pid + 1)

        expect(described_class.service_instance_id).to match(uuid_v4)
        expect(described_class.service_instance_id).not_to eq(id)
      end
    end

    it "puts the service instance ID on every provider's resource" do
      Appsignal::OpenTelemetry.configure(config)

      provider_attributes.each_value do |attrs|
        expect(attrs["service.instance.id"]).to eq(described_class.service_instance_id)
      end
    end

    describe "after a fork" do
      it "gives every provider the new process ID and service instance ID" do
        Appsignal::OpenTelemetry.configure(config)
        parent_id = described_class.service_instance_id

        logs = capture_logs { fork_in_place }

        expect(logs).to be_empty
        provider_attributes.each_value do |attrs|
          expect(attrs["process.pid"]).to eq(Process.pid)
          expect(attrs["service.instance.id"]).to eq(described_class.service_instance_id)
          expect(attrs["service.instance.id"]).not_to eq(parent_id)
          expect(attrs["appsignal.config.name"]).to eq("process-resource-spec")
        end
      end

      it "does nothing when collector mode has not started" do
        expect(described_class.before_fork).to be_nil
        expect { described_class.after_fork(nil) }.not_to raise_error
      end

      it "leaves a provider alone when its service instance ID already changed" do
        Appsignal::OpenTelemetry.configure(config)
        instance_ids = described_class.before_fork
        refreshed = ::OpenTelemetry.meter_provider.resource.merge(
          ::OpenTelemetry::SDK::Resources::Resource.create("service.instance.id" => "other")
        )
        ::OpenTelemetry.meter_provider.instance_variable_set(:@resource, refreshed)
        allow(Process).to receive(:pid).and_return(Process.pid + 1)

        logs = capture_logs { described_class.after_fork(instance_ids) }

        expect(logs).to be_empty
        expect(::OpenTelemetry.meter_provider.resource).to equal(refreshed)
      end

      it "uses a public resource setter when the provider has one" do
        Appsignal::OpenTelemetry.configure(config)
        provider = ::OpenTelemetry.meter_provider
        provider.singleton_class.attr_writer(:resource)
        allow(provider).to receive(:resource=).and_call_original

        logs = capture_logs { fork_in_place }

        expect(logs).to be_empty
        expect(provider).to have_received(:resource=)
        expect(attributes(provider.resource)["process.pid"]).to eq(Process.pid)
      end

      it "logs a warning when a provider's resource can't be read" do
        Appsignal::OpenTelemetry.configure(config)
        instance_ids = described_class.before_fork
        ::OpenTelemetry.meter_provider = Object.new

        logs = capture_logs { described_class.after_fork(instance_ids) }

        expect(logs).to contains_log(
          :warn,
          "Could not refresh the OpenTelemetry resource after fork: " \
            "the meter provider's resource could not be read"
        )
      end

      it "logs a warning when the resource reader doesn't return @resource" do
        Appsignal::OpenTelemetry.configure(config)
        provider = ::OpenTelemetry.meter_provider
        original = provider.resource
        instance_ids = described_class.before_fork
        copy = ::OpenTelemetry::SDK::Resources::Resource.create(attributes(original))
        provider.define_singleton_method(:resource) { copy }

        logs = capture_logs { described_class.after_fork(instance_ids) }

        expect(logs).to contains_log(
          :warn,
          "Could not refresh the OpenTelemetry resource after fork: " \
            "the meter provider's resource could not be read"
        )
        expect(provider.instance_variable_get(:@resource)).to equal(original)
      end

      it "logs a warning when the resource reader returns something other than a resource" do
        Appsignal::OpenTelemetry.configure(config)
        provider = ::OpenTelemetry.meter_provider
        instance_ids = described_class.before_fork
        provider.instance_variable_set(:@resource, "not a resource")
        provider.define_singleton_method(:resource) { @resource }

        logs = capture_logs { described_class.after_fork(instance_ids) }

        expect(logs).to contains_log(
          :warn,
          "Could not refresh the OpenTelemetry resource after fork: " \
            "the meter provider's resource could not be read"
        )
        expect(provider.instance_variable_get(:@resource)).to eq("not a resource")
      end

      it "logs a warning when the provider doesn't keep the new resource" do
        Appsignal::OpenTelemetry.configure(config)
        provider = ::OpenTelemetry.meter_provider
        original = provider.resource
        provider.define_singleton_method(:resource=) { |_resource| nil }

        logs = capture_logs { fork_in_place }

        expect(logs).to contains_log(
          :warn,
          "Could not refresh the OpenTelemetry resource after fork: " \
            "the meter provider did not keep the new resource"
        )
        expect(provider.resource).to equal(original)
      end

      it "logs a warning and doesn't raise when refreshing raises" do
        Appsignal::OpenTelemetry.configure(config)
        instance_ids = described_class.before_fork
        allow(::OpenTelemetry).to receive(:tracer_provider).and_raise(RuntimeError, "boom")

        logs = capture_logs do
          expect { described_class.after_fork(instance_ids) }.not_to raise_error
        end

        expect(logs).to contains_log(
          :warn,
          "Could not refresh the OpenTelemetry resource after fork: RuntimeError: boom"
        )
      end
    end
  end
end
