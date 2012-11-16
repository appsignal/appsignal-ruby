module Appsignal
  module Tracer

    def self.included(klass)
      klass.extend(ClassMethods)
    end

    module ClassMethods
      def appsignal_tracer_for(method_name)
        return unless Appsignal.active
        method_name = method_name.to_s

        trace_method_name = "appsignal_trace_#{method_name.to_s}"
        perform_trace_method_name =
          "appsignal_perform_trace_#{method_name.to_s}"
        send(:define_method, trace_method_name) do |*args, &block|
          appsignal_perform_trace(method_name) do
            send(perform_trace_method_name, *args, &block)
          end
        end

        alias_method perform_trace_method_name, method_name
        alias_method method_name, trace_method_name
      end
    end

    def appsignal_perform_trace(method_name, *args, &block)
      start_time = Time.now
      id = "background_#{SecureRandom.hex(10)}"
      transaction = Appsignal::Transaction.create(id, nil)
      begin
        yield
      rescue Exception => e
        transaction.add_exception(appsignal_exception(e, method_name))
        raise e
      ensure
        unless e
          transaction.set_log_entry(
            appsignal_log_entry(method_name, start_time, Time.now)
          )
        end
        transaction.complete_trace!
      end
    end

    private

    def appsignal_transaction_hash(method_name)
      {
        :action => "#{self.class}##{method_name}",
        :kind => 'background'
      }
    end

    def appsignal_log_entry(method_name, start_time, end_time)
      appsignal_transaction_hash(method_name).merge(
        :duration =>  1000.0 * (end_time - start_time),
        :time => start_time,
        :end => end_time
      )
    end

    def appsignal_exception(e, method_name)
      appsignal_transaction_hash(method_name).merge(
        :exception => {
          :backtrace => e.backtrace,
          :exception => e.class.name,
          :message => e.message
        }
      )
    end
  end
end
