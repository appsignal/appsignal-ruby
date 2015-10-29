if defined?(::Redis)
  Appsignal.logger.info("Loading Redis (#{ Redis::VERSION }) integration")

  ::Redis::Client.class_eval do
    alias process_without_appsignal process

    def process(commands, &block)
      ActiveSupport::Notifications.instrument('query.redis') do
        process_without_appsignal(commands, &block)
      end
    end
  end
end
