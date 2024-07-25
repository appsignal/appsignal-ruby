module ConfigHelpers
  def project_fixture_path
    File.expand_path(
      File.join(File.dirname(__FILE__), "../fixtures/projects/valid")
    )
  end
  module_function :project_fixture_path

  def project_fixture_config( # rubocop:disable Metrics/ParameterLists
    env = "production",
    initial_config = {},
    logger = Appsignal.internal_logger,
    config_file = nil
  )
    Appsignal::Config.new(
      project_fixture_path,
      env,
      initial_config,
      logger,
      config_file
    )
  end
  module_function :project_fixture_config, :project_fixture_path

  def start_agent(env: "production", options: {})
    env = "production" if env == :default
    env ||= "production"
    Appsignal._config = project_fixture_config(env, options)
    Appsignal.start
  end

  def clear_integration_env_vars!
    ENV.delete("RAILS_ENV")
    ENV.delete("RACK_ENV")
    ENV.delete("PADRINO_ENV")
  end
end
