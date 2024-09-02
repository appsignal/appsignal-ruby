module ConfigHelpers
  def project_fixture_path
    File.expand_path(
      File.join(File.dirname(__FILE__), "../fixtures/projects/valid")
    )
  end
  module_function :project_fixture_path

  def rails_project_fixture_path
    File.expand_path(
      File.join(File.dirname(__FILE__), "../fixtures/projects/valid_with_rails_app")
    )
  end
  module_function :rails_project_fixture_path

  def project_fixture_config(
    env = "production",
    options = {},
    logger = Appsignal.internal_logger
  )
    Appsignal::Config.new(
      project_fixture_path,
      env,
      logger
    ).tap do |c|
      c.merge_dsl_options(options)
      c.validate
    end
  end
  module_function :project_fixture_config

  def build_config(
    root_path: project_fixture_path,
    env: "production",
    options: {},
    logger: Appsignal.internal_logger
  )
    Appsignal::Config.new(
      root_path,
      env,
      logger
    ).tap do |c|
      c.merge_dsl_options(options) if options.any?
      c.validate
    end
  end
  module_function :build_config

  def start_agent(env: "production", options: {}, internal_logger: nil)
    env = "production" if env == :default
    env ||= "production"
    Appsignal.configure(env, :root_path => project_fixture_path) do |config|
      options.each do |option, value|
        config.send("#{option}=", value)
      end
    end
    Appsignal.start
    Appsignal.internal_logger = internal_logger if internal_logger
  end

  def clear_integration_env_vars!
    ENV.delete("RAILS_ENV")
    ENV.delete("RACK_ENV")
    ENV.delete("PADRINO_ENV")
  end
end
