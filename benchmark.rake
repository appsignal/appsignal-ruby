require 'appsignal'
require 'benchmark'

GC.disable

task :default => :'benchmark:all'

namespace :benchmark do
  task :all => [:run_inactive, :run_active] do
  end

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
  no_transactions = 10_000

  total_objects = ObjectSpace.count_objects[:TOTAL]
  puts "Initializing, currently #{total_objects} objects"

  Appsignal.config = Appsignal::Config.new(Dir.pwd, 'production', :endpoint => 'http://localhost:8080')
  Appsignal.start
  puts "Appsignal #{Appsignal.active? ? 'active' : 'not active'}"

  puts "Running #{no_transactions} normal transactions"
  puts(Benchmark.measure do
    no_transactions.times do |i|
      request = Appsignal::Transaction::GenericRequest.new(
        :controller => 'HomeController',
        :action     => 'show',
        :params     => {:id => 1}
      )
      Appsignal::Transaction.create("transaction_#{i}", Appsignal::Transaction::HTTP_REQUEST, request)

      ActiveSupport::Notifications.instrument('process_action.action_controller') do
        ActiveSupport::Notifications.instrument('sql.active_record', :sql => 'SELECT `users`.* FROM `users`
                                                                              WHERE `users`.`id` = ?')
        10.times do
          ActiveSupport::Notifications.instrument('sql.active_record', :sql => 'SELECT `todos`.* FROM `todos` WHERE `todos`.`id` = ?')
        end

        ActiveSupport::Notifications.instrument('render_template.action_view', :identifier => 'app/views/home/show.html.erb') do
          5.times do
            ActiveSupport::Notifications.instrument('render_partial.action_view', :identifier => 'app/views/home/_piece.html.erb') do
              3.times do
                ActiveSupport::Notifications.instrument('cache.read')
              end
            end
          end
        end
      end

      Appsignal::Transaction.complete_current!
    end
    puts 'Finished'
  end)

  puts "Done, currently #{ObjectSpace.count_objects[:TOTAL] - total_objects} objects created"
end
