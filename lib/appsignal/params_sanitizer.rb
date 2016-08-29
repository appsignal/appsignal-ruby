module Appsignal
  class ParamsSanitizer
    class << self
      extend Gem::Deprecate

      def sanitize(params)
        Appsignal::Utils::ParamsSanitizer.sanitize(params)
      end

      deprecate :sanitize, "AppSignal::Utils::ParamsSanitizer.sanitize", 2016, 9
    end
  end
end
