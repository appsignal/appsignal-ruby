# frozen_string_literal: true

module Appsignal
  module Utils
    # @!visibility private
    #
    # Converts strings to valid UTF-8. Bytes that are not valid UTF-8 are
    # replaced with U+FFFD.
    module UTF8
      class << self
        # Returns the string itself when it is already valid UTF-8, or a
        # converted copy otherwise.
        #
        # A binary String has no encoding of its own, so its bytes are read as
        # UTF-8. Any other String is converted from its own encoding.
        def encode(string)
          return string if string.encoding == Encoding::UTF_8 && string.valid_encoding?

          if string.encoding == Encoding::BINARY
            String.new(string, :encoding => Encoding::UTF_8).scrub
          else
            string.encode(Encoding::UTF_8, :invalid => :replace, :undef => :replace)
          end
        end
      end
    end
  end
end
