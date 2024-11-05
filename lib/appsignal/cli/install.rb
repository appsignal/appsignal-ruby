# frozen_string_literal: true

require "erb"
require "ostruct"
require "io/console"
require "appsignal/demo"

module Appsignal
  class CLI
    class Install
      extend CLI::Helpers

      EXCLUDED_ENVIRONMENTS = ["test"].freeze

      class << self
        def run(push_api_key, options) # rubocop:disable Metrics/AbcSize
          self.coloring = options.delete(:color) { true }
          $stdout.sync = true

          puts
          puts colorize "############################################", :green
          puts colorize "## Starting AppSignal Installer           ##", :green
          puts colorize "## -------------------------------------- ##", :green
          puts colorize "## Need help?  support@appsignal.com      ##", :green
          puts colorize "## Docs:       https://docs.appsignal.com ##", :green
          puts colorize "############################################", :green
          puts
          unless push_api_key
            puts colorize "Problem encountered:", :red
            puts "  No Push API key entered."
            puts "  - Sign up for AppSignal and follow the instructions"
            puts "  - Already signed up? Click 'Add app' on the account overview page"
            puts
            puts colorize "Exiting installer...", :red
            return
          end
          config = new_config
          config[:push_api_key] = push_api_key

          print "Validating Push API key"
          periods
          puts
          begin
            auth_check = Appsignal::AuthCheck.new(config)
            unless auth_check.perform == "200"
              print colorize("  Error:", :red)
              puts " Push API key '#{config[:push_api_key]}' is not valid. " \
                "Please get a new one at https://appsignal.com/accounts"
              return
            end
          rescue => e
            print colorize("  Error:", :red)
            puts "There was an error validating your Push API key:"
            puts colorize "'#{e}'", :red
            puts "  Please check the Push API key and try again"
            return
          end
          puts colorize "  Push API key valid!", :green
          puts

          if installed_frameworks.include?(:rails)
            install_for_rails(config)
          elsif installed_frameworks.include?(:padrino)
            install_for_padrino(config)
          elsif installed_frameworks.include?(:grape)
            install_for_grape(config)
          elsif installed_frameworks.include?(:hanami)
            install_for_hanami(config)
          elsif installed_frameworks.include?(:sinatra)
            install_for_sinatra(config)
          else
            install_for_unknown_framework(config)
          end
        end

        def install_for_rails(config)
          puts "Installing for Ruby on Rails"

          name_overwritten = configure_rails_app_name(config)
          configure(config, rails_environments, name_overwritten)
          done_notice
        end

        def configure_rails_app_name(config)
          loaded =
            begin
              load Appsignal::Utils::RailsHelper.application_config_path
              true
            rescue LoadError, StandardError
              false
            end

          name_overwritten = false
          if loaded
            config[:name] = Appsignal::Utils::RailsHelper.detected_rails_app_name
            puts
            name_overwritten = yes_or_no(
              "  Your app's name is: '#{config[:name]}' \n  " \
                "Do you want to change how this is displayed in AppSignal? " \
                "(y/n): "
            )
            if name_overwritten
              config[:name] = required_input("  Choose app's display name: ")
              puts
            end
          else
            puts "  Unable to automatically detect your Rails app's name."
            config[:name] = required_input("  Choose your app's display name for AppSignal.com: ")
            puts
          end
          name_overwritten
        end

        def install_for_sinatra(config)
          puts "Installing for Sinatra"
          config[:name] = required_input("  Enter application name: ")
          puts
          configure(config, %w[development production staging], true)

          puts "Sinatra installation"
          puts "  Sinatra apps requires some manual setup."
          puts "  Update the `config.ru` (or the application's main file) to " \
            "look like this:"
          puts
          puts %(require "appsignal")
          puts %(require "sinatra" # or require "sinatra/base")
          puts
          puts "Appsignal.load(:sinatra) # Load the Sinatra integration"
          puts "Appsignal.start # Start AppSignal"
          puts
          puts "# Rest of the config.ru file"
          puts
          puts "  You can find more information in the documentation:"
          puts "  https://docs.appsignal.com/ruby/integrations/sinatra.html"
          press_any_key
          done_notice
        end

        def install_for_padrino(config)
          puts "Installing for Padrino"
          config[:name] = required_input("  Enter application name: ")
          puts
          configure(config, %w[development production staging], true)

          puts "Padrino installation"
          puts "  Padrino apps requires some manual setup."
          puts "  After installing the gem, add the following lines to `config/boot.rb`:"
          puts
          puts %(require "appsignal")
          puts
          puts "Appsignal.load(:padrino) # Load the Padrino integration"
          puts "Appsignal.start # Start AppSignal"
          puts
          puts "  You can find more information in the documentation:"
          puts "  https://docs.appsignal.com/ruby/integrations/padrino.html"
          press_any_key
          done_notice
        end

        def install_for_grape(config)
          puts "Installing for Grape"

          config[:name] = required_input("  Enter application name: ")
          puts

          configure(config, %w[development production staging], true)

          puts "Grape installation"
          puts "  Grape apps require some manual setup."
          puts "  See the installation instructions at:"
          puts "  https://docs.appsignal.com/ruby/integrations/grape.html"
          press_any_key
          done_notice
        end

        def install_for_hanami(config)
          puts "Installing for Hanami"
          config[:name] = required_input("  Enter application name: ")
          puts
          configure(config, %w[development production staging], true)

          puts "Hanami installation"
          puts "  Hanami apps requires some manual setup."
          puts "  Update the config.ru file to include the following:"
          puts
          puts %(  require "appsignal")
          puts %(  require "hanami/boot")
          puts
          puts "Appsignal.load(:hanami) # Load the Hanami integration"
          puts "Appsignal.start # Start AppSignal"
          puts
          puts "# Rest of the config.ru file"
          puts
          puts "  You can find more information in the documentation:"
          puts "  https://docs.appsignal.com/ruby/integrations/hanami.html"
          press_any_key
          done_notice
        end

        def install_for_capistrano
          capfile = File.join(Dir.pwd, "Capfile")
          return unless File.exist?(capfile)
          return if File.read(capfile) =~ %r{require ['|"]appsignal/capistrano}

          puts "Installing for Capistrano"
          print "  Adding AppSignal integration to Capfile"
          File.open(capfile, "a") do |f|
            f.write "\nrequire 'appsignal/capistrano'\n"
          end
          periods
          puts
          puts
        end

        def install_for_unknown_framework(config)
          puts "Installing"
          config[:name] = required_input("  Enter application name: ")
          puts
          configure(config, %w[development production staging], true)

          puts colorize "Warning: We could not detect which framework you are using", :red
          puts "  Some manual installation is most likely required."
          puts "  Please check our documentation for supported libraries: "
          puts "  https://docs.appsignal.com/ruby/integrations.html"
          puts
          puts "  We'd be very grateful if you email us on " \
            "support@appsignal.com with information about your setup."
          press_any_key
          done_notice
        end

        def configure(config, environments, name_overwritten) # rubocop:disable Metrics/AbcSize
          install_for_capistrano

          ENV["APPSIGNAL_APP_ENV"] = "development"

          puts "How do you want to configure AppSignal?"
          puts "  (1) a Ruby config file"
          puts "  (2) a YAML config file (legacy)"
          puts "  (3) environment variables"
          puts
          puts "  See our docs for information on the different configuration methods: "
          puts "  https://docs.appsignal.com/ruby/configuration.html"
          puts
          loop do # rubocop:disable Metrics/BlockLength
            print "  Choose (1-3): "
            case ask_for_input
            when "1"
              puts
              print "Writing Ruby config file"
              periods
              puts
              write_ruby_config_file(
                :push_api_key => config[:push_api_key],
                :app_name => config[:name],
                :environments => environments
              )
              puts colorize "  Config file written to config/appsignal.rb", :green
              puts
              break
            when "2"
              puts
              print "Writing YAML config file"
              periods
              puts
              write_yaml_config_file(
                :push_api_key => config[:push_api_key],
                :app_name => config[:name],
                :environments => environments
              )
              puts colorize "  Config file written to config/appsignal.yml", :green
              puts
              break
            when "3"
              ENV["APPSIGNAL_ACTIVE"] = "true"
              ENV["APPSIGNAL_PUSH_API_KEY"] = config[:push_api_key]
              ENV["APPSIGNAL_APP_NAME"] = config[:name]

              puts
              puts "Add the following environment variables to configure AppSignal:"
              puts "  export APPSIGNAL_PUSH_API_KEY=#{config[:push_api_key]}"
              puts "  export APPSIGNAL_APP_NAME=#{config[:name]}" if name_overwritten
              puts
              puts "  See the documentation for more configuration options:"
              puts "  https://docs.appsignal.com/ruby/configuration.html"
              press_any_key
              break
            end
          end
        end

        def done_notice
          if Gem.win_platform?
            print colorize "Warning:", :red
            puts " The AppSignal agent currently does not work on Microsoft " \
              "Windows. Please push these changes to your staging/production " \
              "environment and make sure some actions are performed. " \
              "AppSignal will pick up your app after a few minutes."
          else
            puts "Sending example data to AppSignal..."
            if Appsignal::Demo.transmit
              puts "  Example data sent!"
              puts "  It may take about a minute for the data to appear on https://appsignal.com/accounts"
            else
              print colorize "Error:", :red
              puts " Couldn't start the AppSignal agent and send example data to AppSignal.com"
              puts "  Please contact us at support@appsignal.com and " \
                "send us a diagnose report using `appsignal diagnose`."
              return
            end
          end
          puts
          puts "Please return to your browser and follow the instructions."
        end

        def installed_frameworks
          [].tap do |out|
            if framework_available?("rails") &&
                File.exist?(Appsignal::Utils::RailsHelper.application_config_path)
              out << :rails
            end
            out << :sinatra if framework_available? "sinatra"
            out << :padrino if framework_available? "padrino"
            out << :grape if framework_available? "grape"
            out << :hanami if framework_available? "hanami"
          end
        end

        def framework_available?(framework_file)
          require framework_file
          true
        rescue LoadError, NameError
          false
        end

        def rails_environments
          Dir.glob(
            File.join(Dir.pwd, "config/environments/*.rb")
          ).map { |o| File.basename(o, ".rb") }.sort - EXCLUDED_ENVIRONMENTS
        end

        def write_ruby_config_file(data)
          template = File.join(
            File.dirname(__FILE__),
            "../../../resources/appsignal.rb.erb"
          )
          write_config_file(
            template,
            File.join(Dir.pwd, "config/appsignal.rb"),
            data
          )
        end

        def write_yaml_config_file(data)
          template = File.join(
            File.dirname(__FILE__),
            "../../../resources/appsignal.yml.erb"
          )
          write_config_file(
            template,
            File.join(Dir.pwd, "config/appsignal.yml"),
            data
          )
        end

        def write_config_file(template_path, path, data)
          file_contents = File.read(template_path)
          template = ERB.new(file_contents, :trim_mode => "-")
          config = template.result(OpenStruct.new(data).instance_eval { binding })

          FileUtils.mkdir_p(File.join(Dir.pwd, "config"))
          File.write(path, config)
        end

        def new_config
          Appsignal::Config.new(Dir.pwd, "")
        end
      end
    end
  end
end
