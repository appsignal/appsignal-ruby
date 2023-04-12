# frozen_string_literal: true

module Appsignal
  class Hooks
    # @api private
    class ActionCableHook < Appsignal::Hooks::Hook
      register :action_cable

      REQUEST_ID = "_appsignal_action_cable.request_id"

      def dependencies_present?
        defined?(::ActiveSupport::Notifications::Instrumenter) &&
          defined?(::ActionCable)
      end

      def install
        require "appsignal/integrations/action_cable"
        ActionCable::Channel::Base.prepend Appsignal::Integrations::ActionCableIntegration

        install_callbacks
      end

      private

      def install_callbacks
        ActionCable::Channel::Base.set_callback :subscribe, :around,
          :prepend => true do |channel, inner|
          # The request is only the original websocket request
          connection = channel.connection
          # #env is not available on the Rails ConnectionStub class used in the
          # Rails app test suite. If we call `#env` it causes an error to occur
          # in apps' test suites.
          env = connection.respond_to?(:env) ? connection.env : {}
          request = ActionDispatch::Request.new(env)
          env[Appsignal::Hooks::ActionCableHook::REQUEST_ID] ||=
            request.request_id || SecureRandom.uuid

          transaction = Appsignal::Transaction.create(
            env[Appsignal::Hooks::ActionCableHook::REQUEST_ID],
            Appsignal::Transaction::ACTION_CABLE,
            request
          )

          begin
            Appsignal.instrument "subscribed.action_cable" do
              inner.call
            end
          rescue Exception => exception # rubocop:disable Lint/RescueException
            transaction.set_error(exception)
            raise exception
          ensure
            transaction.set_action_if_nil("#{channel.class}#subscribed")
            transaction.set_metadata("path", request.path)
            transaction.set_metadata("method", "websocket")
            Appsignal::Transaction.complete_current!
          end
        end

        ActionCable::Channel::Base.set_callback :unsubscribe, :around,
          :prepend => true do |channel, inner|
          # The request is only the original websocket request
          connection = channel.connection
          # #env is not available on the Rails ConnectionStub class used in the
          # Rails app test suite. If we call `#env` it causes an error to occur
          # in apps' test suites.
          env = connection.respond_to?(:env) ? connection.env : {}
          request = ActionDispatch::Request.new(env)
          env[Appsignal::Hooks::ActionCableHook::REQUEST_ID] ||=
            request.request_id || SecureRandom.uuid

          transaction = Appsignal::Transaction.create(
            env[Appsignal::Hooks::ActionCableHook::REQUEST_ID],
            Appsignal::Transaction::ACTION_CABLE,
            request
          )

          begin
            Appsignal.instrument "unsubscribed.action_cable" do
              inner.call
            end
          rescue Exception => exception # rubocop:disable Lint/RescueException
            transaction.set_error(exception)
            raise exception
          ensure
            transaction.set_action_if_nil("#{channel.class}#unsubscribed")
            transaction.set_metadata("path", request.path)
            transaction.set_metadata("method", "websocket")
            Appsignal::Transaction.complete_current!
          end
        end
      end
    end
  end
end
