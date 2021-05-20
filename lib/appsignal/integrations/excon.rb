# frozen_string_literal: true

module Appsignal
  module Integrations
    module ExconIntegration
      def self.instrument(name, datum, &block)
        namespace, *event = name.split(".")
        rails_name = [event, namespace].flatten.join(".")

        title = if rails_name == "response.excon"
                  datum[:host]
                else
                  "#{datum[:method].upcase} #{datum[:scheme]}://#{datum[:host]}"
                end
        Appsignal.instrument(rails_name, title, &block)
      end
    end
  end
end
