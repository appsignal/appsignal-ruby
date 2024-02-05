# frozen_string_literal: true

module Appsignal
  # @api private
  module Rack
    class BodyWrapper
      def self.wrap(original_body, appsignal_transaction_or_nil)
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
        if original_body.respond_to?(:to_path)
          PathableBodyWrapper.new(original_body, appsignal_transaction_or_nil)
        elsif original_body.respond_to?(:to_ary)
          ArrayableBodyWrapper.new(original_body, appsignal_transaction_or_nil)
        elsif !original_body.respond_to?(:each) && original_body.respond_to?(:call)
          CallableBodyWrapper.new(original_body, appsignal_transaction_or_nil)
        else
          EnumerableBodyWrapper.new(original_body, appsignal_transaction_or_nil)
        end
      end

      def initialize(body, appsignal_transaction)
        @body_already_closed = false
        @body = body
        @transaction = appsignal_transaction
      end

      # This must be present in all Rack bodies and will be called by the serving adapter
      def close
        # This is needed so that if `to_ary` of the body has already closed itself
        # (as prescribed) we do not attempt to close it twice
        @body.close if !@body_already_closed && @body.respond_to?(:close)
        @body_already_closed = true
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
    #
    # @api private
    class EnumerableBodyWrapper < BodyWrapper
      def each(&blk)
        # This is a workaround for the Rails bug when there was a bit too much
        # eagerness in implementing to_ary, see 
        # return enum_for(:each) unless block_given?

        @body.each do |bytes|
          yield bytes
        end
      rescue Exception => error # rubocop:disable Lint/RescueException
        @transaction.set_error(error) if @transaction
        raise error
      end
    end

    # The callable response bodies are a new Rack 3.x feature, and would not work
    # with older Rack versions. They must not respond to `each` because
    # "If it responds to each, you must call each and not call". This is why
    # it inherits from BodyWrapper directly and not from EnumerableBodyWrapper
    #
    # @api private
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
        @body_already_closed = true
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
  end
end
