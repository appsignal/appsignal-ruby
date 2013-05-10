namespace :appsignal do

  desc "Show all environments known to appsignal, and if their api key works"
  task :check do
    puts "Checking the configuration and api keys in 'config/appsignal.yml'"
    Appsignal::Config.new(Rails.root, '').load_all.each do |env, config|
      auth_check = ::Appsignal::AuthCheck.new(env)
      puts "[#{env}]"
      puts "  * Configured not to monitor this environment" unless config[:active]
      begin
        result = auth_check.perform
        case result
        when '200'
          puts "  * AppSignal has confirmed authorisation!"
        when '401'
          puts "  * API key not valid with AppSignal..."
        else
          puts "  * Could not confirm authorisation: "\
            "#{result.nil? ? 'nil' : result} at #{auth_check.uri}"
        end
      rescue Exception => e
        puts "Something went wrong while trying to "\
          "authenticate with AppSignal: #{e}"
      end
    end
  end

end
