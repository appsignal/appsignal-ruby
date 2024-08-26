# frozen_string_literal: true

module Appsignal
  module Utils
    class NDJSON
      class << self
        def generate(body)
          body.map do |element|
            Appsignal::Utils::JSON.generate(element)
          end.join("\n")
        end
      end
    end
  end
end
