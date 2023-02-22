# frozen_string_literal: true

module Appsignal
  # System environment detection module.
  #
  # Provides useful methods to find out more about the host system.
  #
  # @api private
  module System
    LINUX_TARGET = "linux".freeze
    LINUX_ARM_ARCHITECTURE = "aarch64".freeze
    MUSL_TARGET = "linux-musl".freeze
    FREEBSD_TARGET = "freebsd".freeze
    GEM_EXT_PATH = File.expand_path("../../../ext", __FILE__).freeze

    def self.heroku?
      ENV.key? "DYNO".freeze
    end

    # Detect agent and extension platform build
    #
    # Used by `ext/*` to select which build it should download and
    # install.
    #
    # - Use `export APPSIGNAL_BUILD_FOR_MUSL=1` if the detection doesn't work
    #   and to force selection of the musl build.
    # - Use `export APPSIGNAL_BUILD_FOR_LINUX_ARM=1` to enable the experimental
    #   Linux ARM build.
    #
    # @api private
    # @return [String]
    def self.agent_platform
      return LINUX_TARGET if force_linux_arm_build?
      return MUSL_TARGET if force_musl_build?

      host_os = RbConfig::CONFIG["host_os"].downcase
      local_os =
        case host_os
        when /#{LINUX_TARGET}/
          LINUX_TARGET
        when /darwin/
          "darwin"
        when /#{FREEBSD_TARGET}/
          FREEBSD_TARGET
        else
          host_os
        end
      if local_os =~ /linux/
        ldd_output = ldd_version_output
        return MUSL_TARGET if ldd_output.include? "musl"
        ldd_version = extract_ldd_version(ldd_output)
        if ldd_version && versionify(ldd_version) < versionify("2.15")
          return MUSL_TARGET
        end
      end

      local_os
    end

    # Detect agent and extension architecture build
    #
    # Used by the `ext/*` tasks to select which architecture build it should download and install.
    #
    # - Use `export APPSIGNAL_BUILD_FOR_LINUX_ARM=1` to enable the experimental
    #   Linux ARM build.
    #
    # @api private
    # @return [String]
    def self.agent_architecture
      return LINUX_ARM_ARCHITECTURE if force_linux_arm_build?

      # Fallback on the Ruby
      RbConfig::CONFIG["host_cpu"]
    end

    # Returns whether or not the musl build was forced by the user.
    #
    # @api private
    def self.force_musl_build?
      %w[true 1].include?(ENV["APPSIGNAL_BUILD_FOR_MUSL"])
    end

    # Returns whether or not the linux ARM build was selected by the user.
    #
    # @api private
    def self.force_linux_arm_build?
      %w[true 1].include?(ENV["APPSIGNAL_BUILD_FOR_LINUX_ARM"])
    end

    # @api private
    def self.versionify(version)
      Gem::Version.new(version)
    end

    # @api private
    def self.ldd_version_output
      `ldd --version 2>&1`
    end

    # @api private
    def self.extract_ldd_version(string)
      ldd_version = string.match(/\d+\.\d+/)
      ldd_version && ldd_version[0]
    end

    def self.jruby?
      RUBY_PLATFORM == "java"
    end
  end
end
