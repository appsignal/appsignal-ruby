module Appsignal
  module CarefulLogger
    def log_error(message)
      if @logger.respond_to?(:important)
        @logger.important(message)
      else
        @logger.error(message)
      end
    end
  end
end
