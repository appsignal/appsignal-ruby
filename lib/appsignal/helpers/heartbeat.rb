# frozen_string_literal: true

module Appsignal
  module Helpers
    module Heartbeat
      def heartbeat(name, &block)
        unless @heartbeat_helper_deprecation_warning_emitted
          callers = caller
          Appsignal::Utils::StdoutAndLoggerMessage.warning \
            "The helper Appsignal.heartbeat has been deprecated. " \
              "Please update the helper call to Appsignal::CheckIn.cron " \
              "in the following file and elsewhere to remove this message.\n#{callers.first}"
          @heartbeat_helper_deprecation_warning_emitted = true
        end
        Appsignal::CheckIn.cron(name, &block)
      end
    end
  end
end
