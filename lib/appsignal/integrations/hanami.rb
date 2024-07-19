# frozen_string_literal: true

require "appsignal"

Appsignal::Utils::StdoutAndLoggerMessage.warning(
  "The 'require \"appsignal/integrations/hanami\"' file require integration " \
    "method is deprecated. " \
    "Please follow the Hanami setup guide in our docs for the new method: " \
    "https://docs.appsignal.com/ruby/integrations/hanami.html"
)

Appsignal.load(:hanami)
Appsignal.start
