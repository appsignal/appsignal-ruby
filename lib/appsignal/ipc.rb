require 'drb/drb'

module Appsignal
  class IPC
    class << self
      def forked!
        Server.stop
        Client.start
        Appsignal.agent.stop_thread
      end
    end

    class Server
      class << self
        attr_reader :uri

        def start
          local_tmp_path = File.join(Appsignal.config.root_path, 'tmp')
          if File.exists?(local_tmp_path)
            @uri = 'drbunix:' + File.join(local_tmp_path, "appsignal-#{Process.pid}")
          else
            @uri = "drbunix:/tmp/appsignal-#{Process.pid}"
          end

          Appsignal.logger.info("Starting IPC server, listening on #{uri}")
          DRb.start_service(uri, Appsignal::IPC::Server)
        end

        def stop
          Appsignal.logger.debug('Stopping IPC server')
          DRb.stop_service
        end

        def enqueue(transaction)
          Appsignal.logger.debug("Receiving transaction #{transaction.request_id} in IPC server")
          Appsignal.enqueue(transaction)
        end
      end
    end

    class Client
      class << self
        attr_reader :server

        def start
          Appsignal.logger.debug('Starting IPC client')
          @server = DRbObject.new_with_uri(Appsignal::IPC::Server.uri)
          @active = true
        end

        def stop
          Appsignal.logger.debug('Stopping IPC client')
          @server = nil
          @active = false
        end

        def enqueue(transaction)
          Appsignal.logger.debug("Sending transaction #{transaction.request_id} in IPC client")
          @server.enqueue(transaction)
        rescue DRb::DRbConnError
          # Try to reconnect and send again
          start
          @server.enqueue(transaction)
        end

        def active?
          !! @active
        end
      end
    end
  end
end
