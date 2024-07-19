# frozen_string_literal: true

module Appsignal
  module Loaders
    class GrapeLoader < Loader
      register :grape

      def on_load
        require "appsignal/rack/grape_middleware"
      end
    end
  end
end
