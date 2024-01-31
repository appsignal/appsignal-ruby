# frozen_string_literal: true

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
    # re-raise errors, but instead log them using the
    # {Appsignal.internal_logger}. This ensures AppSignal will not cause an
    # error in the application when collecting this metadata.
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
          Appsignal.internal_logger.error "Unable to report on environment " \
            "metadata: Unsupported value type for #{key.inspect}"
          return
        end

      yielded_value =
        begin
          yield
        rescue => e
          Appsignal.internal_logger.error \
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
          Appsignal.internal_logger.error "Unable to report on environment " \
            "metadata #{key.inspect}: Unsupported value type for " \
            "#{yielded_value.inspect}"
          return
        end

      Appsignal::Extension.set_environment_metadata(key, value)
    rescue => e
      Appsignal.internal_logger.error "Unable to report on environment " \
        "metadata:\n#{e.class}: #{e}"
    end

    # @see report_supported_gems
    SUPPORTED_GEMS = %w[
      actioncable
      actionmailer
      activejob
      activerecord
      capistrano
      celluloid
      data_mapper
      delayed_job
      dry-monitor
      elasticsearch
      excon
      faraday
      gvltools
      hanami
      hiredis
      mongo_ruby_driver
      padrino
      passenger
      puma
      que
      rack
      rails
      rake
      redis
      redis-client
      resque
      rom
      sequel
      shoryuken
      sidekiq
      sinatra
      unicorn
      webmachine
    ].freeze

    # Report on the list of AppSignal supported gems
    #
    # This list is used to report if which AppSignal supported gems are present
    # in this app and what version. This data will help AppSignal improve its
    # support by knowing what gems and versions of gems it still needs to
    # support or can drop support for.
    #
    # It will ask Bundler to report name and version information from the gems
    # that are present in the app bundle.
    def self.report_supported_gems
      return unless defined?(Bundler) # Do nothing if Bundler is not present

      bundle_gem_specs = ::Bundler.rubygems.all_specs
      SUPPORTED_GEMS.each do |gem_name|
        gem_spec = bundle_gem_specs.find { |spec| spec.name == gem_name }
        next unless gem_spec

        report("ruby_#{gem_name}_version") { gem_spec.version.to_s }
      end
    rescue => e
      Appsignal.internal_logger.error "Unable to report supported gems:\n" \
        "#{e.class}: #{e}"
    end

    def self.report_enabled(feature)
      Appsignal::Environment.report("ruby_#{feature}_enabled") { true }
    rescue => e
      Appsignal.internal_logger.error "Unable to report integration " \
        "enabled:\n#{e.class}: #{e}"
    end
  end
end
