require 'action_dispatch'

module Appsignal
  class Middleware
    def initialize(app, options = {})
      @app, @options = app, options
    end

    def call(env)
      Appsignal::Transaction.create(env['action_dispatch.request_id'], env)
      @app.call(env)
    rescue Exception => exception
      unless in_ignored_exceptions?(exception)
        Appsignal::Transaction.current.add_exception(
          Appsignal::ExceptionNotification.new(env, exception)
        )
      end
      raise exception
    ensure
      Appsignal::Transaction.current.complete!
    end

    private

    def in_ignored_exceptions?(exception)
      Array.wrap(Appsignal.config[:ignore_exceptions]).
        include?(exception.class.name)
    end
  end
end
