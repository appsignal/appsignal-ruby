# frozen_string_literal: true

require "appsignal"

Appsignal::Utils::StdoutAndLoggerMessage.warning(
  "The 'require \"appsignal/integrations/sinatra\"' file require integration " \
    "method is deprecated. " \
    "Please follow the Sinatra setup guide in our docs for the new method: " \
    "https://docs.appsignal.com/ruby/integrations/sinatra.html"
)

Appsignal.load(:sinatra)
Appsignal.start
