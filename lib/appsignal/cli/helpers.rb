# frozen_string_literal: true

require "appsignal/utils/rails_helper"

module Appsignal
  class CLI
    module Helpers
      COLOR_CODES = {
        :red => 31,
        :green => 32,
        :yellow => 33,
        :blue => 34,
        :pink => 35,
        :default => 0
      }.freeze

      private

      def coloring=(value)
        @coloring = value
      end

      def coloring?
        return true unless defined?(@coloring)

        @coloring
      end

      def colorize(text, color)
        return text unless coloring?
        return text if Gem.win_platform?

        reset_color_code = COLOR_CODES.fetch(:default)
        color_code = COLOR_CODES.fetch(color, reset_color_code)

        "\e[#{color_code}m#{text}\e[#{reset_color_code}m"
      end

      def print_empty_line
        puts "\n"
      end

      def rails_present?
        require "rails"
        true
      rescue LoadError
        false
      end

      # The Rails gem being loadable says nothing about the directory the
      # command runs in, so check for the app itself as well.
      def rails_app_present?
        rails_present? &&
          File.exist?(Appsignal::Utils::RailsHelper.environment_config_path)
      end

      def load_rails_app(environment)
        # Pass the environment given as a command line option to the app, so
        # that the AppSignal config file uses it when the app loads it.
        ENV["_APPSIGNAL_CONFIG_FILE_ENV"] = environment
        # Require the railtie manually. It was not loaded when AppSignal
        # loaded, because the `Rails` constant was not present at that point.
        require "appsignal/integrations/railtie"
        # Start the Rails app, including its railties and initializers.
        require Appsignal::Utils::RailsHelper.environment_config_path
      ensure
        ENV.delete("_APPSIGNAL_CONFIG_FILE_ENV")
      end

      # Yields the error when the app fails to load, so that a command can
      # report it in its own way.
      def require_rails_app_if_present(environment)
        return unless rails_app_present?

        load_rails_app(environment)
      rescue LoadError, StandardError => error
        print_empty_line
        puts "ERROR: Error encountered while loading the Rails app"
        puts "#{error.class}: #{error.message}"
        puts error.backtrace
        yield error if block_given?
      end

      def periods
        3.times do
          print "."
          sleep 0.5
        end
      end

      def press_any_key
        puts
        print "  Ready? Press any key:"
        stdin.getc
        puts
        puts
      end

      def ask_for_input
        value = stdin.gets
        value ? value.chomp : ""
      rescue Interrupt
        puts "\nExiting..."
        exit 1
      end

      def required_input(prompt)
        loop do
          print prompt
          value = ask_for_input
          return value unless value.empty?
        end
      end

      def yes_or_no(prompt, options = {})
        loop do
          print prompt
          input = ask_for_input.strip
          input = options[:default] if input.empty? && options[:default]
          case input
          when "y", "Y", "yes"
            return true
          when "n", "N", "no"
            return false
          end
        end
      end

      def stdin
        $stdin
      end
    end
  end
end
