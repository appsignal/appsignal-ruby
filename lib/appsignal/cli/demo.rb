require "appsignal/demo"

module Appsignal
  class CLI
    class Demo
      class << self
        def run(options = {})
          ENV["APPSIGNAL_APP_ENV"] = options[:environment] if options[:environment]

          puts "Sending demonstration sample data..."
          if Appsignal::Demo.transmit
            puts "Demonstration sample data sent!"
            puts "It may take about a minute for the data to appear on AppSignal.com/accounts"
          else
            puts "Error: Unable to start the AppSignal agent and send data to AppSignal.com"
            puts "Please use `appsignal diagnose` to debug your configuration."
            exit 1
          end
        end
      end
    end
  end
end
