module Appsignal
  class Hooks
    class UnicornHook < Appsignal::Hooks::Hook
      register :unicorn

      def dependencies_present?
        defined?(::Unicorn::HttpServer) &&
          defined?(::Unicorn::Worker)
      end

      def install
        # Make sure that appsignal is started and the last transaction
        # in a worker gets flushed.
        #
        # We'd love to be able to hook this into Unicorn in a less
        # intrusive way, but this is the best we can do given the
        # options we have.

        ::Unicorn::HttpServer.class_eval do
          alias worker_loop_without_appsignal worker_loop
          alias kill_worker_without_appsignal kill_worker

          def worker_loop(worker)
            Appsignal.forked
            Appsignal.increment_counter('unicorn_worker_started')
            worker_loop_without_appsignal(worker)
          end

          def kill_worker(signal, wpid)
            Appsignal.increment_counter("unicorn_worker_killed_#{signal}")
            kill_worker_without_appsignal(signal, wpid)
          end
        end

        ::Unicorn::Worker.class_eval do
          alias close_without_appsignal close

          def close
            Appsignal.increment_counter('unicorn_worker_closed')
            Appsignal.stop('unicorn')
            close_without_appsignal
          end
        end
      end
    end
  end
end
