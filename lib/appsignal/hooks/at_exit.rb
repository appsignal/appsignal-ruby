# frozen_string_literal: true

module Appsignal
  class Hooks
    # @api private
    class AtExit < Appsignal::Hooks::Hook
      register :at_exit

      def dependencies_present?
        true
      end

      def install
        Kernel.at_exit(&AtExitCallback.method(:call))
      end

      # Stop AppSignal before the app exists.
      #
      # This is the default behavior and can be customized with the
      # `enable_at_exit_hook` option.
      #
      # When the `enable_at_exit_reporter` option is set to `true` (the
      # default), it will report any unhandled errors that will crash the Ruby
      # process.
      #
      # If this error was previously reported by any of our instrumentation,
      # the error will not also be reported here. This way we don't report an
      # error from a Rake task or instrumented script twice.
      class AtExitCallback
        def self.call
          return unless Appsignal.config&.[](:enable_at_exit_reporter)

          error = $! # rubocop:disable Style/SpecialGlobalVars
          return unless error
          return if ignored_error?(error)
          return if Appsignal::Transaction.last_errors.include?(error)

          Appsignal.report_error(error) do |transaction|
            transaction.set_namespace("unhandled")
          end
        ensure
          Appsignal.stop("at_exit") if Appsignal.config&.[](:enable_at_exit_hook)
        end

        IGNORED_ERRORS = [
          # Normal exits from the application we do not need to report
          SystemExit,
          SignalException
        ].freeze

        def self.ignored_error?(error)
          IGNORED_ERRORS.include?(error.class)
        end
      end
    end
  end
end
