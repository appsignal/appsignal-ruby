module DependencyHelper
  module_function

  def running_jruby?
    defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby"
  end

  def rails_present?
    dependency_present? "rails"
  end

  def sequel_present?
    dependency_present? "sequel"
  end

  def resque_present?
    dependency_present? "resque"
  end

  def redis_present?
    dependency_present? "redis"
  end

  def action_cable_present?
    dependency_present? "actioncable"
  end

  def active_job_present?
    dependency_present? "activejob"
  end

  def active_support_present?
    dependency_present? "activesupport"
  end

  def sinatra_present?
    dependency_present? "sinatra"
  end

  def padrino_present?
    dependency_present? "padrino"
  end

  def grape_present?
    dependency_present? "grape"
  end

  def webmachine_present?
    dependency_present? "webmachine"
  end

  def capistrano_present?
    dependency_present? "capistrano"
  end

  def capistrano2_present?
    capistrano_present? &&
      Gem.loaded_specs["capistrano"].version < Gem::Version.new("3.0")
  end

  def capistrano3_present?
    capistrano_present? &&
      Gem.loaded_specs["capistrano"].version >= Gem::Version.new("3.0")
  end

  def dependency_present?(dependency_file)
    Gem.loaded_specs.key? dependency_file
  end
end
