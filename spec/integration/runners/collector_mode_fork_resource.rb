PROJECT_ROOT = "../../../".freeze
$LOAD_PATH.unshift(File.expand_path("ext", PROJECT_ROOT))
$LOAD_PATH.unshift(File.expand_path("lib", PROJECT_ROOT))

require "appsignal"

Appsignal.start

def emit(process)
  Appsignal.monitor(:action => "#{process}#run") do
    Appsignal.increment_counter("fork_resource_counter", 1, :process => process)
    Appsignal::Logger.new("fork-resource").info("#{process} log")
  end
end

emit("parent")
puts "PARENT_PID=#{Process.pid}"

child_pid = Process.fork do
  puts "CHILD_PID=#{Process.pid}"
  emit("child")
  Appsignal.stop("integration test")
rescue => e
  warn "child failed: #{e.class}: #{e.message}"
  warn e.backtrace
  exit!(1)
end

_, status = Process.waitpid2(child_pid)
Appsignal.stop("integration test")
exit(status.exitstatus || 1)
