# frozen_string_literal: true

module Appsignal
  module Utils
    # @!visibility private
    #
    # Converts strings to valid UTF-8.  Bytes that are not valid UTF-8 are
    # replaced with U+FFFD.
    module UTF8
      class << self
        # Returns the value itself when it is not a String or is already valid
        # UTF-8, or a converted copy otherwise.
        #
        # A binary String has no encoding of its own, so its bytes are read as
        # UTF-8. Any other String is converted from its own encoding.
        def encode(value)
          return value unless value.is_a?(String)
          return value if value.encoding == Encoding::UTF_8 && value.valid_encoding?

          if value.encoding == Encoding::BINARY
            String.new(value, :encoding => Encoding::UTF_8).scrub
          else
            value.encode(Encoding::UTF_8, :invalid => :replace, :undef => :replace)
          end
        end

        # Returns a copy of the given hash with its keys and values converted
        # by {.encode}. It doesn't support nested hashes.
        #
        # All other value types are returned unchanged.
        def encode_hash(hash)
          return hash unless hash.is_a?(Hash)

          hash.to_h { |key, value| [encode(key), encode(value)] }
        end
      end
    end
  end
end
