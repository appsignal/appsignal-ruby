require 'erb'
require 'ostruct'

module Appsignal
  class CLI
    class Install
      EXCLUDED_ENVIRONMENTS = ['test'].freeze

      class << self
        def run(push_api_key, config)
          puts 'Welcome to AppSignal'
          puts "Send us an e-mail at support@appsignal.com if you're stuck or have any questions. We're there to help!"
          puts

          unless push_api_key
            puts 'Please provide the push api key you can find on https://appsignal.com as the first argument:'
            puts
            puts '  bundle exec appsignal install push-api-key'
            puts
            puts 'Exiting'
            return false
          end

          config[:push_api_key] = push_api_key

          print 'Validating api key...'
          begin
            auth_check = Appsignal::AuthCheck.new(config)
            unless auth_check.perform == '200'
              puts "\nApi key '#{config[:push_api_key]}' is not valid, please get a new one on https://appsignal.com"
              return false
            end
          rescue Exception => e
            puts "There was an error validating your api key: '#{e}'"
            puts "Please try again"
            return false
          end
          puts ' Api key valid'

          if installed_frameworks.include?(:rails)
            require File.expand_path(File.join(ENV['PWD'], 'config/application.rb'))

            puts 'Installing for Ruby on Rails'

            config[:name] = Rails.application.class.parent_name

            print "Your application's name is: '#{config[:name]}', do you want to change how this is displayed in AppSignal? (y/n): "
            name_overwritten = gets.chomp == 'y'
            if name_overwritten
              print 'Enter application name: '
              config[:name] = gets.chomp
            end

            configure(config, rails_environments, name_overwritten)

            puts
            puts 'AppSignal has been installed, thank you!'
            puts 'Now commit and push to your test/staging/production environment.'
          elsif installed_frameworks.include?(:sinatra)
            puts 'Installing for Sinatra'

            print 'Enter application name: '
            config[:name] = gets.chomp

            configure(config, ['production', 'staging'], true)

            puts
            puts "Sinatra requires some manual configuration. Add this line beneath require 'sinatra':"
            puts "  require 'appsignal/integrations/sinatra'"
            puts "If your app is a subclass of Sinatra::Base you need to use this middleware:"
            puts "  use Appsignal::Rack::SinatraInstrumentation"
            puts
            puts "You can find more information in the documentation: http://docs.appsignal.com/getting-started/supported-frameworks.html#sinatra"
            puts
            puts 'Now commit and push to your test/staging/production environment.'
          else
            puts "We could not detect which framework you are using. We'll be very grateful if you e-mail ons on support@appsignal.com with information about your setup."
            return false
          end

          true
        end

        def configure(config, environments, name_overwritten)
          print "Do you prefer to configure your applications using environment variables? (y/n): "
          if gets.chomp == 'y'
            puts
            puts "Add the following environment variables to configure AppSignal:"
            puts
            puts "export APPSIGNAL_ACTIVE=true"
            puts "export APPSIGNAL_PUSH_API_KEY=#{config[:push_api_key]}"
            if name_overwritten
              puts "export APPSIGNAL_APP_NAME=#{config[:name]}"
            end
            puts
            puts "See the documentation for more configuration options: http://docs.appsignal.com/gem-settings/configuration.html"
          else
            puts
            puts "Writing config file to config/appsignal.yml"
            write_config_file(
              :push_api_key => config[:push_api_key],
              :app_name => config[:name],
              :environments => environments
            )
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
          end
        end

        def rails_environments
          @environments ||= Dir.glob(
            File.join(ENV['PWD'], 'config/environments/*.rb')
          ).map { |o| File.basename(o, ".rb") }.sort - EXCLUDED_ENVIRONMENTS
        end

        def write_config_file(data)
          template = ERB.new(
            File.read(File.join(File.dirname(__FILE__), "../../../resources/appsignal.yml.erb")),
            nil,
            '-'
          )

          config = template.result(OpenStruct.new(data).instance_eval { binding })

          FileUtils.mkdir_p(File.join(ENV['PWD'], 'config'))
          File.write(File.join(ENV['PWD'], 'config/appsignal.yml'), config)
        end
      end
    end
  end
end
