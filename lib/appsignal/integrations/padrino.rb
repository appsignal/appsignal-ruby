# frozen_string_literal: true

require "appsignal"

Appsignal::Utils::StdoutAndLoggerMessage.warning(
  "The 'require \"appsignal/integrations/padrino\"' file require integration " \
    "method is deprecated. " \
    "Please follow the Padrino setup guide in our docs for the new method: " \
    "https://docs.appsignal.com/ruby/integrations/padrino.html"
)

Appsignal.load(:padrino)
Appsignal.start
