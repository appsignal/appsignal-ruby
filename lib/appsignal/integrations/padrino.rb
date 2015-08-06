require 'appsignal'

module Appsignal::Integrations
  module PadrinoPlugin
    def self.init
      Appsignal.logger.info("Loading Padrino (#{Padrino::VERSION}) integration")

      root             = Padrino.mounted_root
      Appsignal.config = Appsignal::Config.new(root, Padrino.env)

      Appsignal.start_logger(File.join(root, 'log'))
      Appsignal.start

      if Appsignal.active?
        Padrino.use(Appsignal::Rack::Listener)
      end
    end
  end
end

module Padrino::Routing::InstanceMethods
  alias route_without_appsignal route!

  def route!(base = settings, pass_block = nil)
    if env['sinatra.static_file']
      route_without_appsignal(base, pass_block)
    else
      payload = {
        :params  => request.params,
        :session => request.session,
        :method  => request.request_method,
        :path    => request.path
      }
      ActiveSupport::Notifications.instrument('process_action.padrino', payload) do |payload|
        begin
          route_without_appsignal(base, pass_block)
        rescue => e
          Appsignal.add_exception(e); raise e
        ensure
          if defined?(request.route_obj)
            payload[:action] = "#{settings.name}:#{request.route_obj.original_path}"
          else
            payload[:action] = "#{settings.name}:#{request.controller}##{request.action}"
          end
        end
      end
    end
  end
end

Padrino.after_load do
  Appsignal::Integrations::PadrinoPlugin.init
end
