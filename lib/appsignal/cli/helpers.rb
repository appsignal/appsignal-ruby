# frozen_string_literal: true

module Appsignal
  class CLI
    module Helpers
      private

      def detected_rails_app_name
        rails_class = Rails.application.class
        if rails_class.respond_to? :module_parent_name # Rails 6
          rails_class.module_parent_name
        else # Older Rails versions
          rails_class.parent_name
        end
      end

      def colorize(text, color)
        return text if Gem.win_platform?

        color_code =
          case color
          when :red then 31
          when :green then 32
          when :yellow then 33
          when :blue then 34
          when :pink then 35
          else 0
          end

        "\e[#{color_code}m#{text}\e[0m"
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
