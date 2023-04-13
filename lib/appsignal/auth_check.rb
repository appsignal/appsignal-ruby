# frozen_string_literal: true

module Appsignal
  # Class used to perform a Push API validation / authentication check against
  # the AppSignal Push API.
  #
  # @example
  #   config = Appsignal::Config.new(Dir.pwd, "production")
  #   auth_check = Appsignal::AuthCheck.new(config)
  #   # Valid push_api_key
  #   auth_check.perform # => "200"
  #   # Invalid push_api_key
  #   auth_check.perform # => "401"
  #
  # @!attribute [r] config
  #   @return [Appsignal::Config] config to use in the authentication request.
  # @api private
  class AuthCheck
    # Path used on the AppSignal Push API
    # https://push.appsignal.com/1/auth
    ACTION = "auth"

    attr_reader :config

    def initialize(config)
      @config = config
    end

    # Perform push api validation request and return response status code.
    #
    # @return [String] response status code.
    # @raise [StandardError] see {Appsignal::Transmitter#transmit}.
    def perform
      Appsignal::Transmitter.new(ACTION, config).transmit({}).code
    end

    # Perform push api validation request and return a descriptive response
    # tuple.
    #
    # @return [Array<String/nil, String>] response tuple.
    #   - First value is the response status code.
    #   - Second value is a description of the response and the exception error
    #     message if an exception occured.
    def perform_with_result
      status = perform
      result =
        case status
        when "200"
          "AppSignal has confirmed authorization!"
        when "401"
          "API key not valid with AppSignal..."
        else
          "Could not confirm authorization: " \
            "#{status.nil? ? "nil" : status}"
        end
      [status, result]
    rescue => e
      result = "Something went wrong while trying to " \
        "authenticate with AppSignal: #{e}"
      [nil, result]
    end
  end
end
