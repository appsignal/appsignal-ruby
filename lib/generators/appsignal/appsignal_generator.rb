class AppsignalGenerator < Rails::Generators::Base
  source_root File.expand_path('../templates', __FILE__)
  argument :push_key, :type => :string
  class_option :environment, :type => :string, :default => 'production',
    :desc => 'Install AppSignal for a different environment'

  desc "Install the config file for AppSignal with your PUSH_KEY."
  def copy_config_file
    template_file = 'appsignal.yml'
    appsignal_file = File.join('config', template_file)
    if File.exists?(appsignal_file)
      if environment_setup?(appsignal_file)
        say_status :error, "Environment already setup", :red
      else
        append_to_file appsignal_file, "\n"+new_template_content(template_file)
      end
    else
      template template_file, appsignal_file
    end
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
        "use the AppSignal CLI to notify AppSignal of deployments?", :yellow
      say_status "", "Run the following command for help:"
      say_status "", "appsignal notify_of_deploy -h"
    end
  end

  def check_key
    begin
      auth_check = Appsignal::AuthCheck.new(options.environment)
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

  private

  def environment_setup?(config_file)
    file_contents = File.read(config_file)
    file_contents =~ Regexp.new("#{options.environment}:")
  end

  # As based on Thor's template method
  def new_template_content(template_file)
    source  = File.expand_path(find_in_source_paths(template_file.to_s))
    context = instance_eval('binding')
    content = ERB.new(::File.binread(source), nil, '-', '@output_buffer').
      result(context)
  end
end
