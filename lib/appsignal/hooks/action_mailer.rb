# frozen_string_literal: true

module Appsignal
  class Hooks
    class ActionMailerHook < Appsignal::Hooks::Hook
      register :action_mailer

      def dependencies_present?
        defined?(::ActionMailer)
      end

      def install
        ActiveSupport::Notifications
          .subscribe("process.action_mailer") do |_, _, _, _, payload|
          Appsignal.increment_counter(
            :action_mailer_process,
            1,
            :mailer => payload[:mailer], :action => payload[:action]
          )
        end
      end
    end
  end
end
