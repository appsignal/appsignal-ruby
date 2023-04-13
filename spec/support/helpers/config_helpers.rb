module ConfigHelpers
  def project_fixture_path
    File.expand_path(
      File.join(File.dirname(__FILE__), "../fixtures/projects/valid")
    )
  end

  def project_fixture_config(env = "production", initial_config = {}, logger = Appsignal.logger, # rubocop:disable Metrics/ParameterLists
    config_file = nil)
    Appsignal::Config.new(
      project_fixture_path,
      env,
      initial_config,
      logger,
      config_file
    )
  end
  module_function :project_fixture_config, :project_fixture_path

  def start_agent(env = "production")
    Appsignal.config = project_fixture_config(env)
    Appsignal.start
  end
end
