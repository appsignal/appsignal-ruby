module ConfigHelpers
  def project_fixture_path
    File.expand_path(
      File.join(File.dirname(__FILE__),'../project_fixture')
    )
  end

  def project_fixture_log_file
    File.join(project_fixture_path, 'log/appsignal.log')
  end

  def project_fixture_config(env='production', initial_config={}, logger=Logger.new(project_fixture_log_file))
    Appsignal::Config.new(
      project_fixture_path,
      env,
      initial_config,
      logger
    )
  end

  def start_agent(env='production')
    Appsignal.config = project_fixture_config(env)
    Appsignal.start
  end
end
