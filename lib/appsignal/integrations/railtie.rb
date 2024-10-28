# frozen_string_literal: true

Appsignal.internal_logger.debug("Loading Rails (#{Rails.version}) integration")

require "appsignal/utils/rails_helper"
require "appsignal/rack/rails_instrumentation"

module Appsignal
  module Integrations
    # @api private
    class Railtie < ::Rails::Railtie
      config.appsignal = ActiveSupport::OrderedOptions.new
      config.appsignal.start_at = :on_load

      # Run after the Rails framework is loaded
      initializer "appsignal.configure_rails_initialization" do |app|
        Appsignal::Integrations::Railtie.on_load(app)
      end

      # Run after the Rails app's initializers are run
      config.after_initialize do |app|
        Appsignal::Integrations::Railtie.after_initialize(app)
      end

      console do
        Appsignal::Probes.stop
      end

      def self.on_load(app)
        load_default_config
        Appsignal::Integrations::Railtie.add_instrumentation_middleware(app)

        return unless app.config.appsignal.start_at == :on_load

        Appsignal::Integrations::Railtie.start
      end

      def self.after_initialize(app)
        Appsignal::Integrations::Railtie.start if app.config.appsignal.start_at == :after_initialize
      end

      def self.load_default_config
        Appsignal::Config.add_loader_defaults(
          :rails,
          :root_path => Rails.root,
          :env => Rails.env,
          :name => Appsignal::Utils::RailsHelper.detected_rails_app_name,
          :log_path => Rails.root.join("log"),
          :ignore_actions => ["Rails::HealthController#show"]
        )
      end

      def self.start
        Appsignal.start
        initialize_error_reporter if Appsignal.started?
      end

      def self.add_instrumentation_middleware(app)
        app.middleware.insert(
          0,
          ::Rack::Events,
          [Appsignal::Rack::EventHandler.new]
        )
        app.middleware.insert_after(
          ActionDispatch::DebugExceptions,
          Appsignal::Rack::RailsInstrumentation
        )
      end

      def self.initialize_error_reporter
        return unless Appsignal.config[:enable_rails_error_reporter]
        return unless Rails.respond_to?(:error)

        Rails.error.subscribe(Appsignal::Integrations::RailsErrorReporterSubscriber)
      end
    end

    # Report errors reported by the Rails error reporter using {Appsignal.report_error}.
    #
    # @api private
    class RailsErrorReporterSubscriber
      class << self
        def report(error, handled:, severity:, context: {}, source: nil) # rubocop:disable Lint/UnusedMethodArgument
          return if ignored_error?(error)

          is_rails_runner = source == "application.runner.railties"
          namespace, action_name, tags, custom_data = context_for(context.dup)

          Appsignal.report_error(error) do |transaction|
            if namespace
              transaction.set_namespace(namespace)
            elsif is_rails_runner
              transaction.set_namespace("runner")
            end
            transaction.set_action(action_name) if action_name
            transaction.add_custom_data(custom_data) if custom_data

            tags[:reported_by] = :rails_error_reporter
            tags[:severity] = severity
            tags[:source] = source.to_s if source
            transaction.add_tags(tags)
          end
        end

        private

        def ignored_error?(error)
          # We don't need to alert about Sidekiq job internal errors.
          defined?(Sidekiq::JobRetry::Handled) && error.is_a?(Sidekiq::JobRetry::Handled)
        end

        def context_for(context)
          tags = {}

          appsignal_context = context.delete(:appsignal)

          # Use the user override set in the context
          if appsignal_context
            context_namespace = appsignal_context[:namespace]
            namespace = context_namespace if context_namespace

            context_action_name = appsignal_context[:action]
            action_name = context_action_name if context_action_name

            context_custom_data = appsignal_context[:custom_data]
            custom_data = context_custom_data if context_custom_data
          end
          tags.merge!(context)

          [namespace, action_name, tags, custom_data]
        end
      end
    end
  end
end
