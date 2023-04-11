module DependencyHelper
  module_function

  def ruby_version
    Gem::Version.new(RUBY_VERSION)
  end

  def ruby_3_1_or_newer?
    ruby_version >= Gem::Version.new("3.1.0")
  end

  def ruby_3_2_or_newer?
    ruby_version >= Gem::Version.new("3.2.0")
  end

  def running_jruby?
    Appsignal::System.jruby?
  end

  def rails_present?
    dependency_present? "rails"
  end

  def rails6_present?
    rails_present? && rails_version >= Gem::Version.new("6.0.0")
  end

  def rails6_1_present?
    rails_present? && rails_version >= Gem::Version.new("6.1.0")
  end

  def rails6_1_5_present?
    rails_present? && rails_version >= Gem::Version.new("6.1.5")
  end

  def rails7_present?
    rails_present? && rails_version >= Gem::Version.new("7.0.0")
  end

  def active_job_wraps_args?
    rails7_present? || (ruby_3_1_or_newer? && rails6_1_present? && !rails6_1_5_present?)
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

  def http_present?
    dependency_present? "http"
  end

  def que_present?
    dependency_present? "que"
  end

  def hanami_present?
    dependency_present? "hanami"
  end

  def hanami2_present?
    hanami_present? && Gem.loaded_specs["hanami"].version >= Gem::Version.new("2.0")
  end

  def dependency_present?(dependency_file)
    Gem.loaded_specs.key? dependency_file
  end
end
