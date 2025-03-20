# frozen_string_literal: true

module Appsignal
  # @api private
  class InternalError < StandardError; end

  # @api private
  class NotStartedError < InternalError
    MESSAGE = <<~MESSAGE
      The AppSignal Ruby gem was not started!

      This error was raised by calling `Appsignal.check_if_started!`
    MESSAGE

    def message
      MESSAGE
    end
  end
end
