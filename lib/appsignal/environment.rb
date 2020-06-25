module Appsignal
  # @api private
  class Environment
    # Add environment metadata.
    #
    # The key and value of the environment metadata must be a String, even if
    # it's actually of another type.
    #
    # The value of the environment metadata is given as a block that captures
    # errors that might be raised while fetching the value. It will not
    # re-raise errors, but instead log them using the {Appsignal.logger}. This
    # ensures AppSignal will not cause an error in the application when
    # collecting this metadata.
    #
    # @example Reporting a key and value
    #   Appsignal::Environment.report("ruby_version") { RUBY_VERSION }
    #
    # @example When a value is nil
    #   Appsignal::Environment.report("ruby_version") { nil }
    #   # Key and value do not get reported. A warning gets logged instead.
    #
    # @example When an error occurs
    #   Appsignal::Environment.report("ruby_version") { raise "uh oh" }
    #   # Error does not get reraised. A warning gets logged instead.
    #
    # @param key [String] The name of the key of the environment metadata value.
    # @yieldreturn [String] The value of the key of the environment metadata.
    # @return [void]
    def self.report(key)
      key =
        case key
        when String
          key
        else
          Appsignal.logger.error "Unable to report on environment metadata: " \
            "Unsupported value type for #{key.inspect}"
          return
        end

      yielded_value =
        begin
          yield
        rescue => e
          Appsignal.logger.error \
            "Unable to report on environment metadata #{key.inspect}:\n" \
              "#{e.class}: #{e}"
          return
        end

      value =
        case yielded_value
        when TrueClass, FalseClass
          yielded_value.to_s
        when String
          yielded_value
        else
          Appsignal.logger.error "Unable to report on environment metadata " \
            "#{key.inspect}: Unsupported value type for " \
            "#{yielded_value.inspect}"
          return
        end

      Appsignal::Extension.set_environment_metadata(key, value)
    rescue => e
      Appsignal.logger.error "Unable to report on environment metadata:\n" \
        "#{e.class}: #{e}"
    end
  end
end
