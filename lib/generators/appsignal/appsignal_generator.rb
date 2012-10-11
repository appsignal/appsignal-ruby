class AppsignalGenerator < Rails::Generators::Base
  source_root File.expand_path('../templates', __FILE__)
  argument :push_key, :type => :string

  desc "Install the config file for AppSignal with your PUSH_KEY."
  def copy_config_file
    template "appsignal.yml", "config/appsignal.yml"
  end

  def capyistrano_install
    cap_file = File.expand_path(File.join("config", "deploy.rb"))
    if File.exists? cap_file
      file_contents = File.read(cap_file)
      boot_not_loaded =
        (file_contents =~ /require (\'|\").\/config\/boot/).nil?
      appsignal_not_loaded =
        (file_contents =~ /require (\'|\").\/appsignal\/capistrano/).nil?
      if boot_not_loaded
        insert_into_file cap_file, "require './config/boot'\n",
          :after => "require 'bundler/capistrano'\n"
      end
      if appsignal_not_loaded
        insert_into_file cap_file, "require 'appsignal/capistrano'\n",
          :after => "require './config/boot'\n"
      end
    else
      say "No capybara setup detected! Did you know you can use a Rake task" +
      " to notify Appsignal of deployments?"
    end
  end
end
