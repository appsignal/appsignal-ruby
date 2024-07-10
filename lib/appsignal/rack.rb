# frozen_string_literal: true

module Appsignal
  # @api private
  module Rack
    class Utils
      # Fetch the queue start time from the request environment.
      #
      # @since 3.11.0
      # @param env [Hash] Request environment hash.
      # @return [Integer, NilClass]
      def self.queue_start_from(env)
        return unless env

        env_var = env["HTTP_X_QUEUE_START"] || env["HTTP_X_REQUEST_START"]
        return unless env_var

        cleaned_value = env_var.tr("^0-9", "")
        return if cleaned_value.empty?

        value = cleaned_value.to_i
        if value > 4_102_441_200_000
          # Value is in microseconds. Transform to milliseconds.
          value / 1_000
        elsif value < 946_681_200_000
          # Value is too low to be plausible
          nil
        else
          # Value is in milliseconds
          value
        end
      end
    end

    # Alias constants that have moved with a warning message that points to the
    # place to update the reference.
    def self.const_missing(name)
      case name
      when :GenericInstrumentation
        require "appsignal/rack/generic_instrumentation"

        callers = caller
        Appsignal::Utils::StdoutAndLoggerMessage.warning \
          "The constant Appsignal::Rack::GenericInstrumentation has been deprecated. " \
            "Please use the new Appsignal::Rack::InstrumentationMiddleware middleware. " \
            "This new middleware does not default the action name to 'unknown'. " \
            "Set the action name for the endpoint using the Appsignal.set_action helper. " \
            "Read our Rack docs for more information " \
            "https://docs.appsignal.com/ruby/integrations/rack.html " \
            "Update the constant name to " \
            "Appsignal::Rack::InstrumentationMiddleware in the following file to " \
            "remove this message.\n#{callers.first}"
        # Return the alias so it can't ever get stuck in a recursive loop
        Appsignal::Rack::GenericInstrumentationAlias
      else
        super
      end
    end
  end
end
