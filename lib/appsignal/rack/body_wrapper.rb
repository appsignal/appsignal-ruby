# frozen_string_literal: true

module Appsignal
  module Rack
    # @api private
    class BodyWrapper
      IGNORED_ERRORS = [Errno::EPIPE].freeze

      def self.wrap(original_body, appsignal_transaction)
        # The logic of how Rack treats a response body differs based on which methods
        # the body responds to. This means that to support the Rack 3.x spec in full
        # we need to return a wrapper which matches the API of the wrapped body as closely
        # as possible. Pick the wrapper from the most specific to the least specific.
        # See https://github.com/rack/rack/blob/main/SPEC.rdoc#the-body-
        #
        # What is important is that our Body wrapper responds to the same methods Rack
        # (or a webserver) would be checking and calling, and passes through that functionality
        # to the original body.
        #
        # This comment https://github.com/rails/rails/pull/49627#issuecomment-1769802573
        # is of particular interest to understand why this has to be somewhat complicated.
        if original_body.respond_to?(:to_path)
          PathableBodyWrapper.new(original_body, appsignal_transaction)
        elsif original_body.respond_to?(:to_ary)
          ArrayableBodyWrapper.new(original_body, appsignal_transaction)
        elsif !original_body.respond_to?(:each) && original_body.respond_to?(:call)
          # This body only supports #call, so we must be running a Rack 3 application
          # It is possible that a body exposes both `each` and `call` in the hopes of
          # being backwards-compatible with both Rack 3.x and Rack 2.x, however
          # this is not going to work since the SPEC says that if both are available,
          # `each` should be used and `call` should be ignored.
          # So for that case we can drop to our default EnumerableBodyWrapper
          CallableBodyWrapper.new(original_body, appsignal_transaction)
        else
          EnumerableBodyWrapper.new(original_body, appsignal_transaction)
        end
      end

      def initialize(body, appsignal_transaction)
        @body_already_closed = false
        @body = body
        @transaction = appsignal_transaction
      end

      # This must be present in all Rack bodies and will be called by the serving adapter
      def close
        # The @body_already_closed check is needed so that if `to_ary`
        # of the body has already closed itself (as prescribed) we do not
        # attempt to close it twice
        if !@body_already_closed && @body.respond_to?(:close)
          Appsignal.instrument("close_response_body.rack") { @body.close }
        end
        @body_already_closed = true
      rescue *IGNORED_ERRORS # Do not report
        raise
      rescue Exception => error # rubocop:disable Lint/RescueException
        appsignal_report_error(error)
        raise error
      end

      # Return whether the wrapped body responds to the method if this class does not.
      # Based on:
      # https://github.com/rack/rack/blob/0ed580bbe3858ffe5d530adf1bdad9ef9c03407c/lib/rack/body_proxy.rb#L16-L24
      def respond_to_missing?(method_name, include_all = false)
        super || @body.respond_to?(method_name, include_all)
      end

      # Delegate missing methods to the wrapped body.
      # Based on:
      # https://github.com/rack/rack/blob/0ed580bbe3858ffe5d530adf1bdad9ef9c03407c/lib/rack/body_proxy.rb#L44-L61
      def method_missing(method_name, *args, &block)
        @body.__send__(method_name, *args, &block)
      end
      ruby2_keywords(:method_missing) if respond_to?(:ruby2_keywords, true)

      private

      def appsignal_report_error(error)
        @transaction.set_error(error) if appsignal_accepted_error?(error)
      end

      def appsignal_accepted_error?(error)
        return true unless error.cause
        return false if IGNORED_ERRORS.include?(error.cause.class)

        appsignal_accepted_error?(error.cause)
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
        # eagerness in implementing to_ary, see:
        # https://github.com/rails/rails/pull/44953
        # https://github.com/rails/rails/pull/47092
        # https://github.com/rails/rails/pull/49627
        # https://github.com/rails/rails/issues/49588
        # While the Rack SPEC does not mandate `each` to be callable
        # in a blockless way it is still a good idea to have it in place.
        return enum_for(:each) unless block_given?

        Appsignal.instrument("process_response_body.rack", "Process Rack response body (#each)") do
          @body.each(&blk)
        end
      rescue *IGNORED_ERRORS # Do not report
        raise
      rescue Exception => error # rubocop:disable Lint/RescueException
        appsignal_report_error(error)
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
      def call(stream)
        # `stream` will be closed by the app we are calling, no need for us
        # to close it ourselves
        Appsignal.instrument("process_response_body.rack", "Process Rack response body (#call)") do
          @body.call(stream)
        end
      rescue *IGNORED_ERRORS # Do not report
        raise
      rescue Exception => error # rubocop:disable Lint/RescueException
        appsignal_report_error(error)
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
        Appsignal.instrument(
          "process_response_body.rack",
          "Process Rack response body (#to_ary)"
        ) do
          @body.to_ary
        end
      rescue *IGNORED_ERRORS # Do not report
        raise
      rescue Exception => error # rubocop:disable Lint/RescueException
        appsignal_report_error(error)
        raise error
      end
    end

    # Having "to_path" on a body allows Rack to serve out a static file, or to
    # pass that file to the downstream webserver for sending using X-Sendfile
    class PathableBodyWrapper < EnumerableBodyWrapper
      def to_path
        Appsignal.instrument(
          "process_response_body.rack",
          "Process Rack response body (#to_path)"
        ) do
          @body.to_path
        end
      rescue *IGNORED_ERRORS # Do not report
        raise
      rescue Exception => error # rubocop:disable Lint/RescueException
        appsignal_report_error(error)
        raise error
      end
    end
  end
end
