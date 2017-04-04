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
        ActiveSupport::Notifications.subscribe("perform_action.action_cable", Subscriber.new)
      end

      class Subscriber
        def start(_name, id, payload)
          # TODO: Set params and filter them, perferably with Rails param
          # filtering if present. The params given are not filtered.

          # request = ActionDispatch::Request.new(payload)
          Appsignal::Transaction.create(
            id,
            Appsignal::Transaction::ACTION_CABLE,
            {}#,
            # :params_method => :filtered_parameters
          )
        end

        def finish(_name, _id, payload)
          transaction = Appsignal::Transaction.current

          exception = payload[:exception_object]
          transaction.set_error(exception) if exception

          transaction.set_action_if_nil(
            "#{payload[:channel_class]}##{payload[:action]}"
          )
          transaction.set_metadata("method", "websocket")
          transaction.complete
        end
      end
    end
  end
end
