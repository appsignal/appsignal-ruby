# frozen_string_literal: true

module Appsignal
  module Rack
    # Rack instrumentation middleware.
    #
    # This Ruby gem automatically instruments several Rack based libraries,
    # like Rails and Sinatra. This middleware does not need to be added
    # manually to these frameworks.
    #
    # This instrumentation middleware will wrap an app and report how long the
    # request and response took, report errors that occurred in the app, and
    # report metadata about the request method and path.
    #
    # The action name for the endpoint is not set by default, which is required
    # for performance monitoring. Set the action name in each endpoint using
    # the {Appsignal::Helpers::Instrumentation#set_action} helper.
    #
    # If multiple of these middlewares, or
    # {AbstractMiddleware} subclasses are present in an app, only the top
    # middleware will report errors from apps and other middleware.
    #
    # This middleware is best used in combination with the {EventHandler}.
    #
    # @example
    #   # config.ru
    #   require "appsignal"
    #   # Configure and start AppSignal
    #
    #   # Add the EventHandler first
    #   use ::Rack::Events, [Appsignal::Rack::EventHandler.new]
    #   # Add the instrumentation middleware second
    #   use Appsignal::Rack::InstrumentationMiddleware
    #
    #   # Other middleware
    #
    #   # Start app
    #
    # @example Customize instrumentation event category
    #   use Appsignal::Rack::InstrumentationMiddleware,
    #     :instrument_event_name => "custom.goup"
    #
    # @example Disable error reporting for this middleware
    #   use Appsignal::Rack::InstrumentationMiddleware, :report_errors => false
    #
    # @example Always report errors, even when wrapped by other instrumentation middleware
    #   use Appsignal::Rack::InstrumentationMiddleware, :report_errors => true
    #
    # @example Disable error reporting for this middleware based on the request env
    #   use Appsignal::Rack::InstrumentationMiddleware,
    #     :report_errors => lambda { |env| env["some_key"] == "some value" }
    #
    # @see https://docs.appsignal.com/ruby/integrations/rack.html
    # @api public
    class InstrumentationMiddleware < AbstractMiddleware
      def initialize(app, options = {})
        options[:instrument_event_name] ||= "process_request_middleware.rack"
        super
      end
    end
  end
end
