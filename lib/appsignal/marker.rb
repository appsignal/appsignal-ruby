# frozen_string_literal: true

module Appsignal
  # Deploy markers are used on AppSignal.com to indicate changes in an
  # application, "Deploy markers" indicate a deploy of an application.
  #
  # Incidents for exceptions and performance issues will be closed and
  # reopened if they occur again in the new deploy.
  #
  # This class will help send a request to the AppSignal Push API to create a
  # Deploy marker for the application on AppSignal.com.
  #
  # @!attribute [r] marker_data
  #   @return [Hash] marker data to send.
  #
  # @!attribute [r] config
  #   @return [Appsignal::Config] config to use in the authentication request.
  #     Set config does not override data set in {#marker_data}.
  #
  # @see Appsignal::CLI::NotifyOfDeploy
  # @see https://docs.appsignal.com/appsignal/terminology.html#markers
  #   Terminology: Deploy marker
  # @api private
  class Marker
    # Path used on the AppSignal Push API
    # https://push.appsignal.com/1/markers
    ACTION = "markers"

    attr_reader :marker_data, :config

    # @param marker_data [Hash] see {#marker_data}
    # @option marker_data :environment [String] environment to load
    #   configuration for.
    # @option marker_data :name [String] name of the application.
    # @option marker_data :user [String] name of the user that is creating the
    #   marker.
    # @option marker_data :revision [String] the revision that has been
    #   deployed. E.g. a git commit SHA.
    # @param config [Appsignal::Config]
    def initialize(marker_data, config)
      @marker_data = marker_data
      @config = config
    end

    # Send a request to create the marker.
    #
    # Prints output to STDOUT.
    #
    # @return [void]
    def transmit
      transmitter = Transmitter.new(ACTION, config)
      puts "Notifying AppSignal of deploy with: " \
        "revision: #{marker_data[:revision]}, user: #{marker_data[:user]}"

      response = transmitter.transmit(marker_data)
      raise "#{response.code} at #{transmitter.uri}" unless response.code == "200"

      puts "AppSignal has been notified of this deploy!"
    rescue => e
      puts "Something went wrong while trying to notify AppSignal: #{e}"
    end
  end
end
