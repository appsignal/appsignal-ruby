module Appsignal
  class IPC
    attr_reader :reader, :writer, :listener

    def initialize
      Appsignal.logger.debug "Initializing IPC in #{$$}"
      @reader, @writer = IO.pipe
      @listener = Thread.new do
        loop do
          Appsignal.agent.enqueue(Marshal::load(@reader))
        end
      end
      @listening = true
    end

    def write(transaction)
      Marshal::dump(transaction, @writer)
    rescue IOError
      Appsignal.logger.debug "Broken pipe in #{$$}"
      Appsignal.agent.shutdown(true, 'broken pipe')
    end

    def stop_listening!
      Thread.kill(@listener)
      @reader.close unless @reader.closed?
      @listening = false
    end

    def listening?
      !! @listening
    end

    class << self
      def init
        Thread.current[:appsignal_pipe] = Appsignal::IPC.new
      end

      def current
        Thread.current[:appsignal_pipe]
      end
    end
  end
end
