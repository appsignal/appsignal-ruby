module Appsignal
  # System environment detection module.
  #
  # Provides useful methods to find out more about the host system.
  #
  # @api private
  module System
    def self.heroku?
      ENV.key? "DYNO".freeze
    end
  end
end
