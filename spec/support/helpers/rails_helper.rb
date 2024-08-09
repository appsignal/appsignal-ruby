module RailsHelper
  def run_appsignal_railtie
    app = MyApp::Application.new
    Appsignal::Integrations::Railtie.initializers.each do |initializer|
      initializer.run(app)
    end
    ActiveSupport.run_load_hooks(:after_initialize, app)
  end

  def with_rails_error_reporter
    if Rails.respond_to? :error
      clear_rails_error_reporter!
      Appsignal::Integrations::Railtie.initialize_error_reporter
    end
    yield
  ensure
    clear_rails_error_reporter!
  end

  def clear_rails_error_reporter!
    return unless Rails.respond_to? :error

    Rails
      .error
      .instance_variable_get(:@subscribers)
      .reject! { |s| s == Appsignal::Integrations::RailsErrorReporterSubscriber }
  end
end
