# frozen_string_literal: true

module Appsignal
  class InternalError < StandardError; end

  class NotStartedError < InternalError
    # @!visibility private
    MESSAGE = <<~MESSAGE
      The AppSignal Ruby gem was not started!

      This error was raised by calling `Appsignal.check_if_started!`
    MESSAGE

    # @return [String]
    def message
      MESSAGE
    end
  end
end
