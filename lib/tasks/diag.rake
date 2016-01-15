require 'appsignal'
namespace :diag do

  desc "Shows the AppSignal gem version"
  task :gem_version do
    puts "Gem version: #{Appsignal::VERSION}"
  end

  desc "Shows the agent version"
  task :agent_version do
    puts "Agent version: #{Appsignal::Extension.agent_version}"
  end

  desc "Attempt to start appsignal"
  task :start_appsignal do
    Appsignal.start
  end

  desc "Checks if config is present and shows the values"
  task :config => :start_appsignal do
    Appsignal.config.config_hash.each do |key, val|
      puts "Config #{key}: #{val}"
    end
  end

  desc "Checks if required paths are writeable"
  task :paths_writable => :start_appsignal do
    possible_paths = [
      Appsignal.config.root_path,
      Appsignal.config.log_file_path
    ]

    puts "Checking if required paths are writable:"
    possible_paths.each do |path|
      result = File.writable?(path) ? 'Ok' : 'Failed'
      puts "#{path} ...#{result}"
    end
    puts "\n"
  end

  desc "Check if API key is valid"
  task :check_api_key => :start_appsignal do
    auth_check = ::Appsignal::AuthCheck.new(Appsignal.config, Appsignal.logger)
    status, result = auth_check.perform_with_result
    if status == '200'
      puts "Checking API key: Ok"
    else
      puts "Checking API key: Failed"
    end
  end

  desc "Check the ext installation log"
  task :check_ext_install do
    require 'bundler/cli'
    require "bundler/cli/common"
    path     = Bundler::CLI::Common.select_spec('appsignal').full_gem_path
    log_path = "#{path.strip}/ext/install.log"
    puts "Showing last lines of extension install log: #{log_path}"
    puts File.read(log_path)
    puts "\n"
  end

  task :all => [
    "diag:gem_version",
    "diag:agent_version",
    "diag:start_appsignal",
    "diag:config",
    "diag:check_api_key",
    "diag:paths_writable",
    "diag:check_ext_install"
  ]
end
