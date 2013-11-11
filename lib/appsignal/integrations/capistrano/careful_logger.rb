module Appsignal
  module CarefulLogger
    # Because Capistrano's logger uses the term important
    # instead of error.
    def carefully_log_error(message)
      if @logger.respond_to?(:important)
        @logger.important(message)
      else
        @logger.error(message)
      end
    end
  end
end
