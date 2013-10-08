require 'appsignal'

class AppsignalGenerator < Rails::Generators::Base
  EXCLUDED_ENVIRONMENTS = ['test', 'development'].freeze

  source_root File.expand_path('../templates', __FILE__)
  argument :push_api_key, :type => :string
  desc 'Generate a config file for AppSignal'

  def copy_config_file
    template_file = 'appsignal.yml'
    destination_file = File.join('config', template_file)
    if File.exists?(destination_file)
      say_status(:error, 'Looks like you already have a config file', :red)
    else
      template(template_file, destination_file)
      add_appsignal_require_for_capistrano
      check_push_api_key
    end
  end

  protected

  def add_appsignal_require_for_capistrano
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

  def config
    Appsignal::Config.new(
      Rails.root,
      'production'
    )
  end

  def check_push_api_key
    auth_check = ::Appsignal::AuthCheck.new(config, Appsignal.logger)
    status, result = auth_check.perform_with_result
    if status == '200'
      say_status :success, result
    else
      say_status :error, result, :red
    end
  end

  private

  def environments
    @environments ||= Dir.glob(
      File.join(%w(. config environments *.rb))
    ).map { |o| File.basename(o, ".rb") } - EXCLUDED_ENVIRONMENTS
  end
end
