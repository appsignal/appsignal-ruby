# frozen_string_literal: true

module Appsignal
  module Rack
    # @api private
    class HanamiMiddleware < AbstractMiddleware
      def initialize(app, options = {})
        options[:request_class] ||= ::Hanami::Action::Request
        options[:params_method] ||= :params
        options[:instrument_span_name] ||= "process_action.hanami"
        super

        @session_options_key =
          if Gem::Version.new(::Hanami::VERSION) >= Gem::Version.new("2.1.0")
            :session_enabled
          else
            :sessions_enabled
          end
      end

      private

      def params_for(request)
        super&.to_h
      end

      def request_for(env)
        params = ::Hanami::Action.params_class.new(env)
        @request_class.new(
          :env => env,
          :params => params,
          @session_options_key => true
        )
      end
    end
  end
end
