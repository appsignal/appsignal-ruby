PROJECT_ROOT = "../../../".freeze
$LOAD_PATH.unshift(File.expand_path("ext", PROJECT_ROOT))
$LOAD_PATH.unshift(File.expand_path("lib", PROJECT_ROOT))

require "fileutils"
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

  # Use a working directory in the runner's tmp dir to avoid conflicts with the
  # host's /tmp dir
  working_directory = "tmp/appsignal"
  FileUtils.rm_f(working_directory)
  FileUtils.mkdir_p(working_directory)
  config.working_directory_path = File.join(__dir__, working_directory)
end

Appsignal.start

puts "Waiting for USR1 signal..."
# Wait to keep the script alive
loop do
  sleep 0.1
end
