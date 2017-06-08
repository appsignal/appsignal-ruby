module Appsignal
  class Hooks
    # @api private
    class ActionCableHook < Appsignal::Hooks::Hook
      register :action_cable

      def dependencies_present?
        defined?(::ActiveSupport::Notifications::Instrumenter) &&
          defined?(::ActionCable)
      end

      def install
        patch_perform_action
        install_callbacks
      end

      private

      def patch_perform_action
        ActionCable::Channel::Base.class_eval do
          alias_method :original_perform_action, :perform_action

          def perform_action(*args, &block)
            # The request is only the original websocket request
            request = ActionDispatch::Request.new(connection.env)
            transaction = Appsignal::Transaction.create(
              request.request_id,
              Appsignal::Transaction::ACTION_CABLE,
              request
            )

            begin
              original_perform_action(*args, &block)
            rescue => exception
              transaction.set_error(exception)
              raise exception
            ensure
              transaction.set_params(args.first)
              transaction.set_action_if_nil("#{self.class}##{args.first["action"]}")
              transaction.set_metadata("path", request.path)
              transaction.set_metadata("method", "websocket")
              Appsignal::Transaction.complete_current!
            end
          end
        end
      end

      def install_callbacks
        ActionCable::Channel::Base.set_callback :subscribe, :around, :prepend => true do |channel, inner|
          # The request is only the original websocket request
          request = ActionDispatch::Request.new(channel.connection.env)
          transaction = Appsignal::Transaction.create(
            request.request_id,
            Appsignal::Transaction::ACTION_CABLE,
            request
          )

          begin
            inner.call
          rescue => exception
            transaction.set_error(exception)
            raise exception
          ensure
            transaction.set_action_if_nil("#{channel.class}#subscribed")
            transaction.set_metadata("path", request.path)
            transaction.set_metadata("method", "websocket")
            Appsignal::Transaction.complete_current!
          end
        end

        ActionCable::Channel::Base.set_callback :unsubscribe, :around, :prepend => true do |channel, inner|
          # The request is only the original websocket request
          request = ActionDispatch::Request.new(channel.connection.env)
          transaction = Appsignal::Transaction.create(
            request.request_id,
            Appsignal::Transaction::ACTION_CABLE,
            request
          )

          begin
            inner.call
          rescue => exception
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
