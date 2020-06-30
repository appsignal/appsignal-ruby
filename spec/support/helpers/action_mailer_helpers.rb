module ActionMailerHelpers
  def perform_action_mailer(mailer, method, args = nil)
    if DependencyHelper.rails_version >= Gem::Version.new("5.2.0")
      mailer_object =
        if args
          mailer.with(args)
        else
          mailer
        end
      mailer_object.send(method).deliver_later
    else
      # Rails 5.1 and lower
      mailer_object =
        if args
          mailer.send(method, args)
        else
          mailer.send(method)
        end
      mailer_object.deliver_later
    end
  end
end
