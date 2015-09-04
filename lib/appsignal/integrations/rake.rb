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
      Appsignal.monitor_transaction(
        'perform_job.rake',
        :action => name,
        :params => args
      ) do
        invoke_without_appsignal(*args)
      end
    end
  end
end
