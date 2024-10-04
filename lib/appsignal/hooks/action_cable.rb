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

        install_subscribe_callback
        install_unsubscribe_callback
      end

      private

      def install_subscribe_callback
        ActionCable::Channel::Base.set_callback :subscribe, :around,
          :prepend => true do |channel, inner|
          # The request is only the original websocket request
          connection = channel.connection
          # #env is not available on the Rails ConnectionStub class used in the
          # Rails app test suite. If we call `#env` it causes an error to occur
          # in apps' test suites.
          env = connection.respond_to?(:env) ? connection.env : {}
          request = ActionDispatch::Request.new(env)
          request_id = request.request_id || SecureRandom.uuid
          env[Appsignal::Hooks::ActionCableHook::REQUEST_ID] ||= request_id

          transaction =
            Appsignal::Transaction.create(Appsignal::Transaction::ACTION_CABLE)

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
            transaction.add_params_if_nil { request.params }
            transaction.add_headers_if_nil { request.env }
            transaction.add_session_data { request.session.to_h if request.respond_to? :session }
            transaction.add_tags(:request_id => request_id) if request_id
            Appsignal::Transaction.complete_current!
          end
        end
      end

      def install_unsubscribe_callback
        ActionCable::Channel::Base.set_callback :unsubscribe, :around,
          :prepend => true do |channel, inner|
          # The request is only the original websocket request
          connection = channel.connection
          # #env is not available on the Rails ConnectionStub class used in the
          # Rails app test suite. If we call `#env` it causes an error to occur
          # in apps' test suites.
          env = connection.respond_to?(:env) ? connection.env : {}
          request = ActionDispatch::Request.new(env)
          request_id = request.request_id || SecureRandom.uuid
          env[Appsignal::Hooks::ActionCableHook::REQUEST_ID] ||= request_id

          transaction =
            Appsignal::Transaction.create(Appsignal::Transaction::ACTION_CABLE)

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
            transaction.add_params_if_nil { request.params }
            transaction.add_headers_if_nil { request.env }
            transaction.add_session_data { request.session.to_h if request.respond_to? :session }
            transaction.add_tags(:request_id => request_id) if request_id
            Appsignal::Transaction.complete_current!
          end
        end
      end
    end
  end
end
