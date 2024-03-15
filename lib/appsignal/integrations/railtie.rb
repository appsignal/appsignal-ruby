# frozen_string_literal: true

Appsignal.internal_logger.debug("Loading Rails (#{Rails.version}) integration")

require "appsignal/utils/rails_helper"
require "appsignal/rack/rails_instrumentation"

module Appsignal
  module Integrations
    # @api private
    class Railtie < ::Rails::Railtie
      initializer "appsignal.configure_rails_initialization" do |app|
        Appsignal::Integrations::Railtie.initialize_appsignal(app)
      end

      console do
        Appsignal::Minutely.stop
      end

      def self.initialize_appsignal(app)
        # Load config
        Appsignal.config = Appsignal::Config.new(
          Rails.root,
          Rails.env,
          :name => Appsignal::Utils::RailsHelper.detected_rails_app_name,
          :log_path => Rails.root.join("log")
        )

        # Start logger
        Appsignal.start_logger

        app.middleware.insert_after(
          ActionDispatch::DebugExceptions,
          Appsignal::Rack::RailsInstrumentation
        )

        Appsignal.start

        initialize_error_reporter
      end

      def self.initialize_error_reporter
        return unless Appsignal.config[:enable_rails_error_reporter]
        return unless Rails.respond_to?(:error)

        Rails.error.subscribe(Appsignal::Integrations::RailsErrorReporterSubscriber)
      end
    end

    # Report errors reported by the Rails error reporter.
    #
    # We only report that are not reraised by the error reporter, using
    # `Rails.error.handle`.
    # @api private
    class RailsErrorReporterSubscriber
      class << self
        def report(error, handled:, severity:, context: {}, source: nil)
          # Ignore not handled errors. They are reraised by the error reporter
          # and are caught and recorded by our Rails middleware.
          return unless handled

          Appsignal.send_error(error) do |transaction|
            namespace, action_name, path, method, params, tags, custom_data =
              context_for(context.dup)
            transaction.set_namespace(namespace) if namespace
            transaction.set_action(action_name) if action_name
            transaction.set_metadata("path", path)
            transaction.set_metadata("method", method)
            transaction.params = params
            transaction.set_sample_data("custom_data", custom_data) if custom_data

            tags[:severity] = severity
            tags[:source] = source.to_s if source
            transaction.set_tags(tags)
          end
        end

        private

        def context_for(context)
          tags = {}
          custom_data = nil

          appsignal_context = context.delete(:appsignal)
          # Fetch the namespace and action name based on the Rails execution
          # context.
          controller = context.delete(:controller)
          path = nil
          method = nil
          params = nil
          if controller
            namespace = Appsignal::Transaction::HTTP_REQUEST
            action_name = "#{controller.class.name}##{controller.action_name}"
            unless controller.request.nil?
              path = controller.request.path
              method = controller.request.method
              params = controller.request.filtered_parameters
            end
          end
          # ActiveJob transaction naming relies on the current AppSignal
          # transaction namespace and action name copying done after this.
          context.delete(:job)

          # Copy the transaction action name, namespace and other data from
          # the currently active transaction, if not already set.
          if Appsignal::Transaction.current?
            current_transaction = Appsignal::Transaction.current
            namespace = current_transaction.namespace

            transaction_action = current_transaction.action
            action_name = current_transaction.action if transaction_action

            current_tags = current_transaction.tags
            tags.merge!(current_tags) if current_tags
          end

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

          [namespace, action_name, path, method, params, tags, custom_data]
        end
      end
    end
  end
end
