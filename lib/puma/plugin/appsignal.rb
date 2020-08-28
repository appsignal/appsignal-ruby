# AppSignal Puma plugin (Deprecated)
#
# This plugin is deprecated, see the documentation below:
# https://docs.appsignal.com/ruby/integrations/puma.html
Puma::Plugin.create do
  def start(launcher = nil)
    deprecation_message "Deprecated Puma plugin: `:appsignal " \
    "This plugin is deprecated, use the Puma minutely probe as" \
    "described on: https://docs.appsignal.com/ruby/integrations/puma.html"
  end
end
