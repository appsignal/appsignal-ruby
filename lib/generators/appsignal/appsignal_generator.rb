class AppsignalGenerator < Rails::Generators::Base
  source_root File.expand_path('../templates', __FILE__)
  argument :push_key, :type => :string

  desc "Install the config file for AppSignal with your PUSH_KEY."
  def copy_config_file
    template 'appsignal.yml', 'config/appsignal.yml'
  end

  def capyistrano_install
    deploy_file = File.expand_path(File.join('config', 'deploy.rb'))
    cap_file = File.expand_path('Capfile')
    if [deploy_file, cap_file].all? { |file| File.exists?(file) }
      file_contents = File.read(deploy_file)
      if (file_contents =~ /require (\'|\").\/appsignal\/capistrano/).nil?
        append_to_file deploy_file, "\nrequire 'appsignal/capistrano'\n"
      end
    else
      say_status :info, "No capistrano setup detected! Did you know you can "\
        "use a Rake task to notify Appsignal of deployments?", :yellow
      say_status "", "rake appsignal:notify_of_deploy"
    end
  end

  def check_key
    begin
      auth_check = Appsignal::AuthCheck.new
      result = auth_check.perform
      if result == '200'
        say_status :success, "Appsignal has confirmed authorisation!"
      elsif result == '401'
        say_status :error, "Push key not valid with Appsignal...", :red
      else
        say_status :error, "Could not confirm authorisation: "\
          "#{result.nil? ? 'nil' : result} at #{auth_check.uri}", :red
      end
    rescue Exception => e
      say_status :error, "Something went wrong while trying to authenticate "\
        "with Appsignal: #{e}", :red
    end
  end
end
