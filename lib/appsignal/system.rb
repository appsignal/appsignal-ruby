module Appsignal
  # System environment detection module.
  #
  # Provides useful methods to find out more about the host system.
  #
  # @api private
  module System
    MUSL_TARGET = "linux-musl".freeze

    def self.heroku?
      ENV.key? "DYNO".freeze
    end

    # Detect agent and extension platform build
    #
    # Used by ext/extconf.rb to select which build it should download and
    # install.
    #
    # Use `export APPSIGNAL_BUILD_FOR_MUSL=1` if the detection doesn't work
    # and to force selection of the musl build.
    #
    # @api private
    # @return [String]
    def self.agent_platform
      return MUSL_TARGET if ENV["APPSIGNAL_BUILD_FOR_MUSL"]

      local_os = Gem::Platform.local.os
      if local_os =~ /linux/
        ldd_output = ldd_version_output
        return MUSL_TARGET if ldd_output.include? "musl"
        ldd_version = ldd_output.match(/\d+\.\d+/)
        return MUSL_TARGET if ldd_version && ldd_version[0] < "2.15"
      end

      local_os
    end

    # @api private
    def self.ldd_version_output
      `ldd --version 2>&1`
    end
  end
end
