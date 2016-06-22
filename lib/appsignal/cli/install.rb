require 'erb'
require 'ostruct'
require 'io/console'

module Appsignal
  class CLI
    class Install
      EXCLUDED_ENVIRONMENTS = ['test'].freeze

      class << self
        def run(push_api_key, config)
          puts
          puts colorize "#######################################", :green
          puts colorize "## Starting AppSignal Installer      ##", :green
          puts colorize "## --------------------------------- ##", :green
          puts colorize "## Need help?  support@appsignal.com ##", :green
          puts colorize "## Docs?       docs.appsignal.com    ##", :green
          puts colorize "#######################################", :green
          puts
          unless push_api_key
            puts colorize 'Problem encountered:', :red
            puts '  No push API key entered.'
            puts '  - Sign up for AppSignal and follow the instructions'
            puts "  - Already signed up? Click 'New app' on the account overview page"
            puts
            puts colorize 'Exiting installer...', :red
            return false
          end

          config[:push_api_key] = push_api_key

          print 'Validating API key'
          periods
          puts
          begin
            auth_check = Appsignal::AuthCheck.new(config)
            unless auth_check.perform == '200'
              puts "\n  API key '#{config[:push_api_key]}' is not valid, please get a new one on https://appsignal.com"
              return false
            end
          rescue Exception => e
            puts "  There was an error validating your API key:"
            puts colorize "'#{e}'", :red
            puts "  Please try again"
            return false
          end
          puts colorize '  API key valid!', :green
          puts

          if installed_frameworks.include?(:rails)
            install_for_rails(config)
          elsif installed_frameworks.include?(:sinatra) && !installed_frameworks.include?(:padrino)
            install_for_sinatra(config)
          elsif installed_frameworks.include?(:padrino)
            install_for_padrino(config)
          elsif installed_frameworks.include?(:grape)
            install_for_grape(config)
          else
            puts "We could not detect which framework you are using. We'd be very grateful if you email us on support@appsignal.com with information about your setup."
            return false
          end

          true
        end

        def install_for_rails(config)
          require File.expand_path(File.join(Dir.pwd, 'config/application.rb'))

          puts 'Installing for Ruby on Rails'

          config[:name] = Rails.application.class.parent_name

          name_overwritten = yes_or_no("  Your app's name is: '#{config[:name]}' \n  Do you want to change how this is displayed in AppSignal? (y/n): ")
          puts
          if name_overwritten
            config[:name] = required_input("  Choose app's display name: ")
            puts
          end

          configure(config, rails_environments, name_overwritten)
          done_notice
        end

        def install_for_sinatra(config)
          puts 'Installing for Sinatra'
          config[:name] = required_input('  Enter application name: ')
          puts
          configure(config, ['production', 'staging'], true)

          puts "Finish Sinatra configuration"
          puts "  Sinatra requires some manual configuration."
          puts "  Add this line beneath require 'sinatra':"
          puts
          puts "  require 'appsignal/integrations/sinatra'"
          press_any_key
          puts "Configure subclass apps"
          puts "  If your app is a subclass of Sinatra::Base you need to use this middleware:"
          puts
          puts "  use Appsignal::Rack::SinatraInstrumentation"
          press_any_key
          done_notice
        end

        def install_for_padrino(config)
          puts 'Installing for Padrino'

          config[:name] = required_input('  Enter application name: ')
          puts

          configure(config, ['production', 'staging'], true)

          puts "Finish Padrino installation"
          puts "  Padrino requires some manual configuration."
          puts "  After installing the gem, add the following line to /config/boot.rb:"
          puts
          puts "  require 'appsignal/integrations/padrino"
          puts
          puts "  You can find more information in the documentation:"
          puts "  http://docs.appsignal.com/getting-started/supported-frameworks.html#padrino"
          press_any_key
          done_notice
        end

        def install_for_grape(config)
          puts 'Installing for Grape'

          config[:name] = required_input('  Enter application name: ')
          puts

          configure(config, ['production', 'staging'], true)

          puts "Manual Grape configuration needed"
          puts "  See the installation instructions here:"
          puts "  http://docs.appsignal.com/getting-started/supported-frameworks.html#grape"
          press_any_key
          done_notice
        end

        def colorize(text, color)
          return text if Gem.win_platform?
          color_code = case color
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
            sleep(0.5)
          end
        end

        def press_any_key
          puts
          print "  Ready? Press any key:"
          STDIN.getch
          puts
          puts
        end

        def yes_or_no(prompt)
          loop do
            print prompt
            input = gets.chomp
            if input == 'y'
              return true
            elsif input == 'n'
              return false
            end
          end
        end

        def required_input(prompt)
          loop do
            print prompt
            input = gets.chomp
            if input.length > 0
              return input
            end
          end
        end

        def configure(config, environments, name_overwritten)
          deploy_rb_file = File.join(Dir.pwd, 'config/deploy.rb')
          if File.exists?(deploy_rb_file) && (File.read(deploy_rb_file) =~ /require (\'|\").\/appsignal\/capistrano/).nil?
            print 'Adding AppSignal integration to deploy.rb'
            File.open(deploy_rb_file, 'a') do |f|
              f.write "\nrequire 'appsignal/capistrano'\n"
            end
            periods
            puts
            puts
          end

          puts "How do you want to configure AppSignal?"
          puts "  (1) a config file"
          puts "  (2) environment variables"
          loop do
            print "  Choose (1/2): "
            input = gets.chomp
            if input == '1'
              puts
              print "Writing config file"
              periods
              puts
              puts colorize "  Config file written to config/appsignal.yml", :green
              write_config_file(
                :push_api_key => config[:push_api_key],
                :app_name => config[:name],
                :environments => environments
              )
              puts
              break
            elsif input == '2'
              puts
              puts "Add the following environment variables to configure AppSignal:"
              puts "  export APPSIGNAL_ACTIVE=true"
              puts "  export APPSIGNAL_PUSH_API_KEY=#{config[:push_api_key]}"
              if name_overwritten
                puts "  export APPSIGNAL_APP_NAME=#{config[:name]}"
              end
              puts
              puts "  See the documentation for more configuration options:"
              puts "  http://docs.appsignal.com/gem-settings/configuration.html"
              press_any_key
              break
            end
          end
        end

        def done_notice
          sleep 0.3
          puts colorize "#####################################", :green
          puts colorize "## AppSignal installation complete ##", :green
          puts colorize "#####################################", :green
          sleep 0.3
          puts
          puts '  Now you need to send us some data...'
          puts
          if Gem.win_platform?
            puts 'The AppSignal agent currently does not work on Windows, please push these changes to your test/staging/production environment'
          else
            puts "  Run your app with AppSignal activated:"
            puts "  - You can do this on your dev environment"
            puts "  - Or deploy to staging or production"
            puts
            puts "  Test if AppSignal is receiving data:"
            puts "  - Requests > 200ms are shown in AppSignal"
            puts "  - Generate an error to test (e.g. add .xml to a url)"
            puts
            puts "Please return to your browser and follow the instructions."
          end
        end

        def installed_frameworks
          [].tap do |out|
            begin
              require 'rails'
              out << :rails
            rescue LoadError
            end
            begin
              require 'sinatra'
              out << :sinatra
            rescue LoadError
            end
            begin
              require 'padrino'
              out << :padrino
            rescue LoadError
            end
            begin
              require 'grape'
              out << :grape
            rescue LoadError
            end
          end
        end

        def rails_environments
          @environments ||= Dir.glob(
            File.join(Dir.pwd, 'config/environments/*.rb')
          ).map { |o| File.basename(o, ".rb") }.sort - EXCLUDED_ENVIRONMENTS
        end

        def write_config_file(data)
          template = ERB.new(
            File.read(File.join(File.dirname(__FILE__), "../../../resources/appsignal.yml.erb")),
            nil,
            '-'
          )

          config = template.result(OpenStruct.new(data).instance_eval { binding })

          FileUtils.mkdir_p(File.join(Dir.pwd, 'config'))
          File.write(File.join(Dir.pwd, 'config/appsignal.yml'), config)
        end
      end
    end
  end
end
