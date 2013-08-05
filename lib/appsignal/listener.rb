require 'action_dispatch'

module Appsignal
  class Listener
    def initialize(app, options = {})
      @app, @options = app, options
    end

    def call(env)
      Appsignal::Transaction.create(env['action_dispatch.request_id'], env)
      @app.call(env)
    rescue Exception => exception
      unless Appsignal.is_ignored_exception?(exception)
        Appsignal::Transaction.current.add_exception(exception)
      end
      raise exception
    ensure
      Appsignal::Transaction.current.complete!
    end
  end
end
