# frozen_string_literal: true

module Appsignal
  module Integrations
    # @api private
    module ResqueActiveJobPlugin
      def self.included(_)
        callers = caller
        Appsignal::Utils::DeprecationMessage.message \
          "The AppSignal ResqueActiveJobPlugin is deprecated and does " \
          "nothing on extend. In this version of the AppSignal Ruby gem " \
          "the integration with Resque is automatic on all Resque workers. " \
          "Please remove the following line from this file to remove this " \
          "message: include Appsignal::Integrations::ResqueActiveJobPlugin\n" \
          "#{callers.first}"
      end
    end
  end
end
