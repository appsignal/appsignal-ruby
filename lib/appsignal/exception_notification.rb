module Appsignal
  class MissingController
    def method_missing(*args, &block)
    end
  end

  class ExceptionNotification
    attr_reader :env, :exception, :backtrace

    def initialize(env, exception, run_rails_cleaner=true)
      @env = env
      @exception = exception
      if run_rails_cleaner && Rails.respond_to?(:backtrace_cleaner)
        @backtrace = Rails.backtrace_cleaner.clean(@exception.backtrace, nil)
      else
        @backtrace = @exception.backtrace
      end
    end

    def name
      @exception.class.name
    end

    def message
      @exception.message
    end
  end
end
