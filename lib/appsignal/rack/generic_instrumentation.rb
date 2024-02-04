# frozen_string_literal: true

require "rack"

module Appsignal
  # @api private
  module Rack
    class GenericInstrumentation
      class BodyWrapper
        def initialize(body, appsignal_transaction)
          @body = body
          @transaction = appsignal_transaction
        end

        # This must be present in all Rack bodies and will be called by the serving adapter
        def close
          @body.close if @body.respond_to?(:close)
        rescue Exception => error # rubocop:disable Lint/RescueException
          @transaction.set_error(error) if @transaction
          raise error
        ensure
          @transaction.complete if @transaction
        end
      end

      # The standard Rack body wrapper which exposes "each" for iterating
      # over the response body. This is supported across all 3 major Rack
      # versions.
      class EnumerableBodyWrapper < BodyWrapper
        def each(&blk)
          return enum_for(:each) unless block_given?

          @body.each do |bytes|
            yield bytes
          end
        rescue Exception => error # rubocop:disable Lint/RescueException
          @transaction.set_error(error) if @transaction
          raise error
        end
      end

      # The callable wrapper is a new Rack 3.x feature, and would not work
      # with older Rack versions. Also, it must not respond to `each` because
      # "If it responds to each, you must call each and not call".
      class CallableBodyWrapper < BodyWrapper
        def call(_stream)
          @body.call(_stream)
        rescue Exception => error # rubocop:disable Lint/RescueException
          @transaction.set_error(error) if @transaction
          raise error
        end
      end

      # "to_ary" takes precedence over "each" and allows the response body
      # to be read eagerly. If the body supports that method, it takes precedence
      # over "each":
      # "Middleware may call to_ary directly on the Body and return a new Body in its place"
      # One could "fold" both the to_ary API and the each() API into one Body object, but
      # to_ary must also call "close" after it executes - and in the Rails implementation
      # this pecularity was not handled properly.
      #
      # @api private
      class ArrayableBodyWrapper < EnumerableBodyWrapper
        def to_ary
          @body.to_ary
        rescue Exception => error # rubocop:disable Lint/RescueException
          @transaction.set_error(error) if @transaction
          raise error
        ensure
          close
        end
      end

      # Having "to_path" on a body allows Rack to serve out a static file, or to
      # pass that file to the downstream webserver for sending using X-Sendfile
      class PathableBodyWrapper < EnumerableBodyWrapper
        def to_path
          @body.to_path
        rescue Exception => error # rubocop:disable Lint/RescueException
          @transaction.set_error(error) if @transaction
          raise error
        end
      end

      def initialize(app, options = {})
        Appsignal.internal_logger.debug "Initializing #{self.class.to_s}"
        @app = app
        @options = options
      end

      def call(env)
        if Appsignal.active?
          call_with_appsignal_monitoring(env)
        else
          # Create the same body wrapping as when we are monitoring a transaction,
          # so that the behavior of the Rack stack does not change just because
          # Appsignal is off. Rack treats bodies in a special way which also
          # differs between Rack versions, so it is important to keep it consistent
          status, headers, obody = @app.call(env)
          [status, headers, wrap_body(obody, _transaction = nil)]
        end
      end

      def call_with_appsignal_monitoring(env)
        request = ::Rack::Request.new(env)
        transaction = Appsignal::Transaction.create(
          SecureRandom.uuid,
          Appsignal::Transaction::HTTP_REQUEST,
          request
        )
        begin
          transaction.set_http_or_background_queue_start
          Appsignal.instrument("process_action.rack") do
            status, headers, body = @app.call(env)
            [status, headers, wrap_body(body, transaction)]
          end
        rescue Exception => error # rubocop:disable Lint/RescueException
          transaction.set_error(error)
          raise error
        ensure
          transaction.set_action_if_nil(env["appsignal.route"] || "unknown")
          transaction.set_metadata("path", request.path)
          transaction.set_metadata("method", request.request_method)
        end
      end

      def wrap_body(obody, transaction)
        # The logic of how Rack treats a response body differs based on which methods
        # the body responds to. This means that to support the Rack 3.x spec in full
        # we need to return a wrapper which matches the API of the wrapped body as closely
        # as possible. Pick the wrapper from the most specific to the least specific.
        # See https://github.com/rack/rack/blob/main/SPEC.rdoc#the-body-
        #
        # What is important is that our Body wrapper responds to the same methods Rack
        # (or a webserver) would be checking and calling, and passes through that functionality
        # to the original body. This can be done using delegation via i.e. SimpleDelegate
        # but we also need "close" to get called correctly so that the Appsignal transaction
        # gets completed - which will not happen, for example, when #to_ary gets called
        # just on the delegated Rack body.
        if obody.respond_to?(:to_path)
          PathableBodyWrapper.new(obody, transaction)
        elsif obody.respond_to?(:to_ary)
          ArrayableBodyWrapper.new(obody, transaction)
        elsif !obody.respond_to?(:each) && obody.respond_to?(:call)
          CallableBodyWrapper.new(obody, transaction)
        else
          EnumerableBodyWrapper.new(obody, transaction)
        end
      end
    end
  end
end
