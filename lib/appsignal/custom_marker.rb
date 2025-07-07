# frozen_string_literal: true

module Appsignal
  # Custom markers are used on AppSignal.com to indicate events in an
  # application, to give additional context on graph timelines.
  #
  # This helper class will send a request to the AppSignal public endpoint to
  # create a Custom marker for the application on AppSignal.com.
  #
  # @see https://docs.appsignal.com/api/public-endpoint/custom-markers.html
  #   Public Endpoint API markers endpoint documentation
  # @see https://docs.appsignal.com/appsignal/terminology.html#markers
  #   Terminology: Markers
  class CustomMarker
    # @param icon [String] icon to use for the marker, like an emoji.
    # @param message [String] name of the user that is creating the
    #   marker.
    # @param created_at [Time, String] A Ruby time object or a valid ISO8601
    #   timestamp.
    # @return [Boolean]
    def self.report(
      icon: nil,
      message: nil,
      created_at: nil
    )
      new(
        {
          :icon => icon,
          :message => message,
          :created_at => created_at.respond_to?(:iso8601) ? created_at.iso8601 : created_at
        }.compact
      ).transmit
    end

    # @!visibility private
    def initialize(marker_data)
      @marker_data = marker_data
    end

    # @!visibility private
    def transmit
      unless Appsignal.config
        Appsignal.internal_logger.warn(
          "Did not transmit custom marker: no AppSignal config loaded"
        )
        return false
      end

      transmitter = Transmitter.new(
        "#{Appsignal.config[:logging_endpoint]}/markers",
        Appsignal.config
      )
      response = transmitter.transmit(@marker_data)

      if (200...300).include?(response.code.to_i)
        Appsignal.internal_logger.info("Transmitted custom marker")
        true
      else
        Appsignal.internal_logger.error(
          "Failed to transmit custom marker: #{response.code} status code"
        )
        false
      end
    rescue => e
      Appsignal.internal_logger.error(
        "Failed to transmit custom marker: #{e.class}: #{e.message}\n" \
          "#{e.backtrace}"
      )
      false
    end
  end
end
