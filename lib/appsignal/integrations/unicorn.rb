# frozen_string_literal: true

module Appsignal
  module Integrations
    module UnicornIntegration
      # Make sure that appsignal is started and the last transaction
      # in a worker gets flushed.
      #
      # We'd love to be able to hook this into Unicorn in a less
      # intrusive way, but this is the best we can do given the
      # options we have.

      module Server
        def worker_loop(worker)
          Appsignal.forked
          super
        end
      end

      module Worker
        def close
          Appsignal.stop("unicorn")
          super
        end
      end
    end
  end
end
