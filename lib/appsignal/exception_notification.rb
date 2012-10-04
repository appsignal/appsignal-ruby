module Appsignal
  class MissingController

    def method_missing(*args, &block)
    end
  end

  class ExceptionNotification

    attr_reader :env, :exception, :kontroller, :request, :backtrace

    def initialize(env, exception)
      @exception  = exception
      @backtrace  = Rails.respond_to?(:backtrace_cleaner) ?
          Rails.backtrace_cleaner.send(:filter, exception.backtrace) :
          exception.backtrace
    end

    def name
      @exception.class.name
    end

    def message
      @exception.message
    end
  end
end
