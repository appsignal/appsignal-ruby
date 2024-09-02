# frozen_string_literal: true

module Appsignal
  module Integrations
    # @api private
    module PumaServer
      def lowlevel_error(error, env, response_status = 500)
        response =
          if method(:lowlevel_error).super_method.arity.abs == 3 # Puma >= 5
            super
          else # Puma <= 4
            super(error, env)
          end

        unless PumaServerHelper.ignored_error?(error)
          Appsignal.report_error(error) do |transaction|
            Appsignal::Rack::ApplyRackRequest
              .new(::Rack::Request.new(env))
              .apply_to(transaction)
            transaction.add_tags(
              :reported_by => :puma_lowlevel_error,
              :response_status => response_status
            )
          end
        end

        response
      end
    end

    module PumaServerHelper
      IGNORED_ERRORS = [
        # Ignore internal Puma Client IO errors
        # https://github.com/puma/puma/blob/9ee922d28e1fffd02c1d5480a9e13376f92f46a3/lib/puma/server.rb#L536-L544
        "Puma::MiniSSL::SSLError",
        "Puma::HttpParserError",
        "Puma::HttpParserError501"
      ].freeze

      def self.ignored_error?(error)
        IGNORED_ERRORS.include?(error.class.to_s)
      end
    end
  end
end
