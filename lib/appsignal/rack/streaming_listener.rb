# Appsignal module that tracks exceptions in Streaming rack responses.
module Appsignal
  module Rack
    class StreamingListener
      def initialize(app, options = {})
        Appsignal.logger.debug 'Initializing Appsignal::Rack::StreamingListener'
        @app, @options = app, options
      end

      def call(env)
        if Appsignal.active?
          call_with_appsignal_monitoring(env)
        else
          @app.call(env)
        end
      end

      def call_with_appsignal_monitoring(env)
        transaction = Appsignal::Transaction.create(SecureRandom.uuid, env)
        streaming   = false

        # Instrument a `process_action`, to set params/action name
        status, headers, body = ActiveSupport::Notifications
          .instrument('process_action.rack', raw_payload(env)) do |payload|
          begin
            @app.call(env)
          rescue Exception => e
            transaction.add_exception(e); raise e;
          ensure
            payload[:action] = env['appsignal.action']
          end
        end

        # Wrap the result body with our StreamWrapper
        [status, headers, StreamWrapper.new(body, transaction)]
      end

      def raw_payload(env)
        request = ::Rack::Request.new(env)
        {
          :params  => request.params,
          :session => request.session,
          :method  => request.request_method,
          :path    => request.path
        }
      end
    end
  end

  class StreamWrapper
    def initialize(stream, transaction)
       @stream      = stream
       @transaction = transaction
    end

    def each
      @stream.each { |c| yield(c) }
    rescue Exception => e
      @transaction.add_exception(e); raise e
    end

    def close
      @stream.close if @stream.respond_to?(:close)
    rescue Exception => e
      @transaction.add_exception(e); raise e
    ensure
      @transaction.complete!
    end
  end
end
