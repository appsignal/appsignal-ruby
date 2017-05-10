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
        ActionCable::Channel::Base.class_eval do
          alias_method :original_perform_action, :perform_action

          def perform_action(*args, &block)
            # Request is only the original websocket request
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
              # Cannot do this because it gets overwritten with the
              # request.params from the original websocket request. We cannot
              # set the params here right now, unless we make it possible to
              # customize the params in the transaction.
              # transaction.set_params(args.first)
              # and use that when it is set, otherwise fall back on the
              # request.params
              # transaction.set_sample_data(:params, args.first)

              transaction.set_action_if_nil("#{self.class}##{args.first["action"]}")
              transaction.set_metadata("path", request.path)
              transaction.set_metadata("method", "websocket")
              Appsignal::Transaction.complete_current!
            end
          end
        end

        ActionCable::Channel::Base.set_callback :subscribe, :around, :prepend => true do |channel, inner|
          # Request is only the original websocket request
          request = ActionDispatch::Request.new(channel.connection.env)
          transaction = Appsignal::Transaction.create(
            request.request_id,
            Appsignal::Transaction::ACTION_CABLE,
            request
          )

          begin
            inner.call
          ensure
            # Cannot do this, only ask for the params from the orignal websocket request
            # transaction.set_sample_data(:params, channel.params)
            transaction.set_action_if_nil("#{channel.class}#subscribed")
            transaction.set_metadata("path", request.path)
            transaction.set_metadata("method", "websocket")
            Appsignal::Transaction.complete_current!
          end
        end

        ActionCable::Channel::Base.set_callback :unsubscribe, :around, :prepend => true do |channel, inner|
          # Request is only the original websocket request
          request = ActionDispatch::Request.new(channel.connection.env)
          transaction = Appsignal::Transaction.create(
            request.request_id,
            Appsignal::Transaction::ACTION_CABLE,
            request
          )

          begin
            inner.call
          ensure
            # Cannot do this, only ask for the params from the orignal websocket request
            # transaction.set_sample_data(:params, channel.params)
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
