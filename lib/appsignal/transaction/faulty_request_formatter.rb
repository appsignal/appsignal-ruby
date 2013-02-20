module Appsignal
  class TransactionFormatter
    class FaultyRequestFormatter < Appsignal::TransactionFormatter

      def to_hash
        super.merge :exception => formatted_exception
      end

      protected

      def_delegators :exception, :backtrace, :name, :message

      def formatted_exception
        {
          :backtrace => backtrace,
          :exception => name,
          :message => message
        }
      end

      def action
        if process_action_event
          super
        else
          exception.exception.inspect.gsub(/^#<([^>]*)>$/, '\1')
        end
      end

      def basic_process_action_event
        super.merge(
          :environment => filtered_environment,
          :session_data => request.session
        )
      end

    end
  end
end
