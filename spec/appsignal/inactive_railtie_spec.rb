require 'spec_helper'

describe "Inactive Appsignal::Railtie" do
  it "should not insert itself into the middleware stack" do
    # This uses a hack because Rails really dislikes you trying to
    # start multiple applications in one process. This works decently
    # on every platform except JRuby, so we're disabling this test on
    # JRuby for now.
    unless RUBY_PLATFORM == "java"
      pid = fork do
        Appsignal.stub(:active => false)
        Rails.application = nil
        instance_eval do
          module MyTempApp
            class Application < Rails::Application
              config.active_support.deprecation = proc { |message, stack| }
            end
          end
        end
        MyTempApp::Application.initialize!

        MyTempApp::Application.middleware.to_a.should_not include Appsignal::Middleware
      end
      Process.wait(pid)
      raise 'Example failed' unless $?.exitstatus == 0
    end
  end
end
