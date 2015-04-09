module Appsignal
  class ZippedPayload
    attr_reader :body

    def initialize(given_body)
      @body = Zlib::Deflate.deflate(
        JSON.generate(given_body, :quirks_mode => true),
        Zlib::BEST_SPEED
      )
    end

  end
end
