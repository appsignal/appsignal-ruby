# frozen_string_literal: true

module Appsignal
  module Integrations
    # @api private
    module ResquePlugin
      def self.extended(_)
        callers = caller
        Appsignal::Utils::DeprecationMessage.message \
          "The AppSignal ResquePlugin is deprecated and does " \
          "nothing on extend. In this version of the AppSignal Ruby gem " \
          "the integration with Resque is automatic on all Resque workers. " \
          "Please remove the following line from this file to remove this " \
          "message: extend Appsignal::Integrations::ResquePlugin\n" \
          "#{callers.first}"
      end
    end
  end
end
