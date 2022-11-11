# frozen_string_literal: true

module Appsignal
  module Integrations
    module HttpIntegration
      def request(verb, uri, opts = {})
        Appsignal.instrument("request.http_rb", "#{verb.upcase} #{uri}") do
          super
        end
      end
    end
  end
end
