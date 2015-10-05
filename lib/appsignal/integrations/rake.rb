module Rake
  class Task
    alias_method :invoke_without_appsignal, :invoke

    def invoke(*args)
      if Appsignal.active?
        invoke_with_appsignal(*args)
      else
        invoke_without_appsignal(*args)
      end
    end

    def invoke_with_appsignal(*args)
      invoke_without_appsignal(*args)
    rescue => error
      transaction = Appsignal::Transaction.create(
        SecureRandom.uuid,
        Appsignal::Transaction::BACKGROUND_JOB,
        Appsignal::Transaction::GenericRequest.new(
          :params => args
        )
      )
      transaction.set_action(name)
      transaction.set_error(error)
      transaction.complete!
      Appsignal.stop
      raise error
    end
  end
end
