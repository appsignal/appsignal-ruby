module Appsignal
  module Tracer

    def self.included(klass)
      klass.extend(ClassMethods)
    end

    module ClassMethods
      def tracer_for(method_name)
        method_name = method_name.to_s

        trace_method_name = "appsignal_trace_#{method_name.to_s}"
        perform_trace_method_name = "appsignal_perform_trace_#{method_name.to_s}"
        send(:define_method, trace_method_name) do |*args, &block|
          perform_trace(method_name) do
            send(perform_trace_method_name, *args, &block)
          end
        end

        alias_method perform_trace_method_name, method_name
        alias_method method_name, trace_method_name
      end
    end

    def perform_trace(method_name, *args, &block)
      start_time = Time.now
      id = "background_#{SecureRandom.hex(10)}"
      transaction = Appsignal::Transaction.create(id, 'env')
      begin
        yield
      rescue Exception => e
        transaction.add_exception(exception(e, method_name))
        raise e
      ensure
        unless e
          transaction.set_log_entry(log_entry(method_name, start_time, Time.now))
        end
        transaction.complete!
      end
    end

    private

    def transaction_hash(method_name)
      {
        :action => "#{self.class}##{method_name}",
        :kind => 'background'
      }
    end

    def log_entry(method_name, start_time, end_time)
      transaction_hash(method_name).merge(
        :duration =>  1000.0 * (end_time - start_time),
        :time => start_time,
        :end => end_time
      )
    end

    def exception(e, method_name)
      transaction_hash(method_name).merge(
        :exception => {
          :backtrace => e.backtrace,
          :exception => e.class.name,
          :message => e.message
        }
      )
    end
  end
end
