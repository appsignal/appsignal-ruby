require 'appsignal'

class AppsignalGenerator < Rails::Generators::Base
  EXCLUDED_ENVIRONMENTS = [:test].freeze

  source_root File.expand_path('../templates', __FILE__)
  argument :environment, :type => :string
  argument :push_key, :type => :string
  desc "Install the config file for AppSignal with your PUSH_KEY."

  def copy_config_file
    template_file = 'appsignal.yml'
    appsignal_file = File.join('config', template_file)
    if File.exists?(appsignal_file)
      say_status(:error, "Looks like you already have a config file.", :red)
      say_status(:error, "Add the following to config/appsignal.yml:\n\n", :red)
      say_status(:error, "#{environment}:", :red)
      say_status(:error, "  api_key: #{push_key}\n\n", :red)
      say_status(:info, "Then run:\n\n", :red)
      say_status(:info, "  appsignal api_check", :red)
    else
      template template_file, appsignal_file
      capyistrano_install
      check_key
    end
  end

  protected

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
      auth_check = ::Appsignal::AuthCheck.new(environment)
      result = auth_check.perform
      if result == '200'
        say_status :success, "AppSignal has confirmed authorisation!"
      elsif result == '401'
        say_status :error, "Push key not valid with AppSignal...", :red
      else
        say_status :error, "Could not confirm authorisation: "\
          "#{result.nil? ? 'nil' : result}", :red
      end
    rescue Exception => e
      say_status :error, "Something went wrong while trying to authenticate "\
        "with AppSignal: #{e}", :red
    end
  end

  private

  alias :selected_environment :environment

  def environments
    @environments ||= Dir.glob(
      File.join(%w(. config environments *.rb))
    ).map { |o| File.basename(o, ".rb").to_sym } - EXCLUDED_ENVIRONMENTS
  end

  def environment_setup?(config_file)
    file_contents = File.read(config_file)
    file_contents =~ Regexp.new("#{environment}:")
  end

  # As based on Thor's template method
  def new_template_content(template_file)
    source  = File.expand_path(find_in_source_paths(template_file.to_s))
    context = instance_eval('binding')
    content = ERB.new(::File.binread(source), nil, '-', '@output_buffer').
      result(context)
  end
end
