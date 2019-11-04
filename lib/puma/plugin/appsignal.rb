APPSIGNAL_PUMA_PLUGIN_LOADED = true

# AppSignal Puma plugin
#
# This plugin ensures the minutely probe thread is started with the Puma
# minutely probe in the Puma master process.
#
# The constant {APPSIGNAL_PUMA_PLUGIN_LOADED} is here to mark the Plugin as
# loaded by the rest of the AppSignal gem. This ensures that the Puma minutely
# probe is not also started in every Puma workers, which was the old behavior.
# See {Appsignal::Hooks::PumaHook#install} for more information.
#
# For even more information:
# https://docs.appsignal.com/ruby/integrations/puma.html
Puma::Plugin.create do
  def start(launcher = nil)
    launcher.events.on_booted do
      require "appsignal"
      if ::Puma.respond_to?(:stats)
        Appsignal::Minutely.probes.register :puma, Appsignal::Hooks::PumaProbe
      end
      Appsignal.start
      Appsignal.start_logger
    end
  end
end
