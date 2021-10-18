module DependencyHelper
  module_function

  def ruby_version
    Gem::Version.new(RUBY_VERSION)
  end

  def running_ruby_2_0?
    ruby_version.segments.take(2) == [2, 0]
  end

  def running_jruby?
    defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby"
  end

  def rails_present?
    dependency_present? "rails"
  end

  def rails6_present?
    rails_present? && rails_version >= Gem::Version.new("6.0.0")
  end

  def rails_version
    Gem.loaded_specs["rails"].version
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

  def action_mailer_present?
    dependency_present? "actionmailer"
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

  def que_present?
    dependency_present? "que"
  end

  def dependency_present?(dependency_file)
    Gem.loaded_specs.key? dependency_file
  end
end
