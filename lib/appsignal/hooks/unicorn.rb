# frozen_string_literal: true

module Appsignal
  class Hooks
    # @api private
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

          def worker_loop(worker)
            Appsignal.forked
            worker_loop_without_appsignal(worker)
          end
        end

        ::Unicorn::Worker.class_eval do
          alias close_without_appsignal close

          def close
            Appsignal.stop("unicorn")
            close_without_appsignal
          end
        end
      end
    end
  end
end
