module ActionMailerHelpers
  def perform_action_mailer(mailer, method, args = nil)
    if DependencyHelper.rails_version >= Gem::Version.new("5.2.0")
      case args
      when Array
        mailer.send(method, *args).deliver_later
      when Hash
        mailer.with(args).send(method).deliver_later
      when NilClass
        mailer.send(method).deliver_later
      else
        raise "Unknown scenario for arguments: #{args}"
      end
    else
      # Rails 5.1 and lower
      mailer_object =
        if args
          mailer.send(method, *args)
        else
          mailer.send(method)
        end
      mailer_object.deliver_later
    end
  end
end
