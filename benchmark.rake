# frozen_string_literal: true

# Run using: rake --rakefile benchmark.rake [tasks]

$LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), "lib"))

require "benchmark"
require "benchmark/ips"
require "appsignal"

def process_rss
  `ps -o rss= -p #{Process.pid}`.to_i
end

GC.disable

task :default => :"benchmark:all"

namespace :benchmark do
  task :all => [:memory_inactive, :memory_active, :ips]

  task :memory_inactive do
    puts "Memory benchmark with AppSignal off"
    ENV["APPSIGNAL_PUSH_API_KEY"] = nil
    run_benchmark
  end

  task :memory_active do
    puts "Memory benchmark with AppSignal on"
    ENV["APPSIGNAL_PUSH_API_KEY"] = "something"
    run_benchmark
  end

  task :ips do
    puts "Iterations per second benchmark"
    start_agent
    Benchmark.ips do |x|
      x.config(
        :time => 5,
        :warmup => 2
      )

      x.report("monitor transaction inactive") do |times|
        ENV["APPSIGNAL_PUSH_API_KEY"] = nil

        monitor_transaction("transaction_#{times}")
      end

      x.report("monitor transaction active") do |times|
        ENV["APPSIGNAL_PUSH_API_KEY"] = "something"

        monitor_transaction("transaction_#{times}")
      end

      x.compare!
    end
  end
end

def start_agent
  Appsignal.configure(:production) do |config|
    config.endpoint = "http://localhost:8080"
  end
  Appsignal.start
end

def monitor_transaction(transaction_id)
  transaction = Appsignal::Transaction.create(
    transaction_id,
    Appsignal::Transaction::HTTP_REQUEST
  )
  transaction.set_action("HomeController#show")
  transaction.add_params(:id => 1)

  Appsignal.instrument("process_action.action_controller") do
    Appsignal.instrument_sql(
      "sql.active_record",
      nil,
      "SELECT `users`.* FROM `users` WHERE `users`.`id` = ?"
    )
    10.times do
      Appsignal.instrument_sql(
        "sql.active_record",
        nil,
        "SELECT `todos`.* FROM `todos` WHERE `todos`.`id` = ?"
      )
    end

    Appsignal.instrument(
      "render_template.action_view",
      "app/views/home/show.html.erb"
    ) do
      5.times do
        Appsignal.instrument(
          "render_partial.action_view",
          "app/views/home/_piece.html.erb"
        ) do
          3.times do
            Appsignal.instrument("cache.read")
          end
        end
      end
    end
  end

  Appsignal::Transaction.complete_current!
end

def run_benchmark
  no_transactions = (ENV["NO_TRANSACTIONS"] || 100_000).to_i
  no_threads = (ENV["NO_THREADS"] || 1).to_i

  total_objects = ObjectSpace.count_objects[:TOTAL]
  puts "Initializing, currently #{total_objects} objects"
  puts "RSS: #{process_rss}"

  start_agent
  puts "Appsignal #{Appsignal.active? ? "active" : "not active"}"

  threads = []
  puts "Running #{no_transactions} normal transactions in #{no_threads} threads"
  puts(Benchmark.measure do
    no_threads.times do
      thread = Thread.new do
        no_transactions.times do |i|
          monitor_transaction("transaction_#{i}")
        end
      end
      thread.abort_on_exception = true
      threads << thread
    end
    threads.each(&:join)
    puts "Finished"
  end)

  puts "Done, currently #{ObjectSpace.count_objects[:TOTAL] - total_objects} objects created"
  puts "RSS: #{process_rss}"
end
