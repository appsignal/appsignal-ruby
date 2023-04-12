# frozen_string_literal: true

require "appsignal/utils/rails_helper"

module Appsignal
  class CLI
    module Helpers
      private

      COLOR_CODES = {
        :red => 31,
        :green => 32,
        :yellow => 33,
        :blue => 34,
        :pink => 35,
        :default => 0
      }.freeze

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
