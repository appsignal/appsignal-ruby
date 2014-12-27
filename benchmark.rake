require 'appsignal'
require 'benchmark'

class ::Appsignal::EventFormatter::ActiveRecord::SqlFormatter
  def connection_config; {:adapter => 'mysql'}; end
end

GC.disable

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
  no_transactions = 100

  total_objects = ObjectSpace.count_objects[:TOTAL]
  puts "Initializing, currently #{total_objects} objects"

  Appsignal.config = Appsignal::Config.new('', 'production')
  Appsignal.start
  puts "Appsignal #{Appsignal.active? ? 'active' : 'not active'}"

  puts "Running #{no_transactions} normal transactions"
  puts(Benchmark.measure do
    no_transactions.times do |i|
      transaction_id = "transaction_#{i}"
      ActiveSupport::Notifications.instrumenter.instance_variable_set(:@id, transaction_id)
      Appsignal::Transaction.create("transaction_#{i}", {})

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

      ActiveSupport::Notifications.instrument(
        'process_action.action_controller',
        :controller => 'HomeController',
        :action     => 'show',
        :params     => {:id => 1}
      )

      if i == 10 || i == 60
        puts 'Sleeping'
        sleep(2)
      end
      Appsignal::Transaction.complete_current!
    end
    puts 'Finished'
  end)

  if Appsignal.active?
    puts "Running aggregator to_hash for #{Appsignal.agent.aggregator.transactions.length} transactions"
    puts(Benchmark.measure do
      Appsignal.agent.aggregator.to_json
    end)
  end

  puts "Done, currently #{ObjectSpace.count_objects[:TOTAL] - total_objects} objects created"
end
