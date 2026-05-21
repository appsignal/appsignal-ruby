PROJECT_ROOT = "../../../".freeze
$LOAD_PATH.unshift(File.expand_path("ext", PROJECT_ROOT))
$LOAD_PATH.unshift(File.expand_path("lib", PROJECT_ROOT))

require "appsignal"

Signal.trap("USR1") do
  puts "Received USR1 signal"
  Appsignal.stop("trap")
  puts "AppSignal has shut down without raising an error"
  exit 0
end

# Dummy config
Appsignal.configure(:test) do |config|
  config.active = true
  config.push_api_key = "abc"
  config.name = "Signal app"
end

Appsignal.start

puts "Waiting for USR1 signal..."
# Wait to keep the script alive
loop do
  sleep 0.1
end
