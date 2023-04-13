describe Appsignal::Hooks::ActionMailerHook do
  if DependencyHelper.action_mailer_present? &&
      DependencyHelper.rails_version >= Gem::Version.new("4.0.0")
    context "with ActionMailer" do
      require "action_mailer"

      class UserMailer < ActionMailer::Base
        default :from => "test@example.com"

        def welcome
          mail(:to => "test@example.com", :subject => "ActionMailer test",
            :content_type => "text/html") do |format|
            format.html { render :html => "This is a test" }
          end
        end
      end
      UserMailer.delivery_method = :test

      describe ".dependencies_present?" do
        subject { described_class.new.dependencies_present? }

        it "returns true" do
          is_expected.to be_truthy
        end
      end

      describe ".install" do
        before do
          start_agent
          expect(Appsignal.active?).to be_truthy
        end

        it "is subscribed to 'process.action_mailer' and processes instrumentation" do
          expect(Appsignal).to receive(:increment_counter).with(
            :action_mailer_process,
            1,
            :mailer => "UserMailer", :action => :welcome
          )

          UserMailer.welcome.deliver_now
        end
      end
    end
  else
    context "without ActionMailer" do
      describe ".dependencies_present?" do
        subject { described_class.new.dependencies_present? }

        it "returns false" do
          is_expected.to be_falsy
        end
      end
    end
  end
end
