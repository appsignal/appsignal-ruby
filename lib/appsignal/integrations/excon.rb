# frozen_string_literal: true

module Appsignal
  module Integrations
    module ExconIntegration
      def self.instrument(name, data, &block)
        namespace, *event = name.split(".")
        rails_name = [event, namespace].flatten.join(".")

        title =
          if rails_name == "response.excon"
            data[:host]
          else
            "#{data[:method].to_s.upcase} #{data[:scheme]}://#{data[:host]}"
          end
        Appsignal.instrument(rails_name, title, &block)
      end
    end
  end
end
