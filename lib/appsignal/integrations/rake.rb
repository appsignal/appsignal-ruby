module Rake
  class Task
    alias_method :invoke_without_appsignal, :invoke

    def invoke(*args)
      invoke_with_appsignal(*args)
    end

    def invoke_with_appsignal(*args)
      transaction = Appsignal::Transaction.create(
        SecureRandom.uuid,
        ENV,
        :kind => 'background_job',
        :action => name,
        :params => args
      )

      invoke_without_appsignal(*args)
    rescue => exception
      unless Appsignal.is_ignored_exception?(exception)
        transaction.add_exception(exception)
      end
      raise exception
    ensure
      transaction.complete!
      Appsignal.agent.send_queue if Appsignal.active?
    end
  end
end
