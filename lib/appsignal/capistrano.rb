require 'appsignal'

if defined?(Capistrano::VERSION)
  # Capistrano 3+
  load File.expand_path('../integrations/capistrano/appsignal.cap', __FILE__)
else
  # Capistrano 2
  require 'appsignal/integrations/capistrano/capistrano_2_tasks'
end
