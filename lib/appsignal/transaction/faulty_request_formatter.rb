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
        log_entry ? super : exception.exception.inspect.gsub(/^#<([^>]*)>$/, '\1')
      end

    end
  end
end
