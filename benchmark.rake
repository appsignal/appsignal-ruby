require 'appsignal'
require 'benchmark'

def process_rss
  `ps -o rss= -p #{Process.pid}`.to_i
end

GC.disable

task :default => :'benchmark:all'

namespace :benchmark do
  task :all => [:run_inactive, :run_active]

  task :run_inactive do
    puts 'Running with appsignal off'
    ENV['APPSIGNAL_PUSH_API_KEY'] = nil
    run_benchmark
  end

  task :run_active do
    puts 'Running with appsignal on'
    ENV['APPSIGNAL_PUSH_API_KEY'] = 'something'
    run_benchmark
  end
end

def run_benchmark
  no_transactions = (ENV['NO_TRANSACTIONS'] || 100_000).to_i
  no_threads = (ENV['NO_THREADS'] || 1).to_i

  total_objects = ObjectSpace.count_objects[:TOTAL]
  puts "Initializing, currently #{total_objects} objects"
  puts "RSS: #{process_rss}"

  Appsignal.config = Appsignal::Config.new(Dir.pwd, 'production', :endpoint => 'http://localhost:8080')
  Appsignal.start
  puts "Appsignal #{Appsignal.active? ? 'active' : 'not active'}"

  threads = []
  puts "Running #{no_transactions} normal transactions in #{no_threads} threads"
  puts(Benchmark.measure do
    no_threads.times do
      thread = Thread.new do
        no_transactions.times do |i|
          request = Appsignal::Transaction::GenericRequest.new(
            :controller => 'HomeController',
            :action     => 'show',
            :params     => {:id => 1}
          )
          Appsignal::Transaction.create("transaction_#{i}", Appsignal::Transaction::HTTP_REQUEST, request)

          Appsignal.instrument('process_action.action_controller') do
            Appsignal.instrument_sql('sql.active_record', nil, 'SELECT `users`.* FROM `users` WHERE `users`.`id` = ?')
            10.times do
              Appsignal.instrument_sql('sql.active_record', nil, 'SELECT `todos`.* FROM `todos` WHERE `todos`.`id` = ?')
            end

            Appsignal.instrument('render_template.action_view', 'app/views/home/show.html.erb') do
              5.times do
                Appsignal.instrument('render_partial.action_view', 'app/views/home/_piece.html.erb') do
                  3.times do
                    Appsignal.instrument('cache.read')
                  end
                end
              end
            end
          end

          Appsignal::Transaction.complete_current!
        end
      end
      thread.abort_on_exception = true
      threads << thread
    end

    threads.each(&:join)
    puts 'Finished'
  end)

  puts "Done, currently #{ObjectSpace.count_objects[:TOTAL] - total_objects} objects created"
  puts "RSS: #{process_rss}"
end
