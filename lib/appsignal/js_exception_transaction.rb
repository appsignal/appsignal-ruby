module Appsignal
  class JSExceptionTransaction

    def initialize(data)
      @data = data
      @time = Time.now.to_i
    end

    def type
      :exception
    end

    def action
      @data['action']
    end

    def clear_events!; end
    def convert_values_to_primitives!; end
    def events; []; end

    def to_hash
      {
        :request_id => SecureRandom.uuid,
        :log_entry => {
          :action      => action,
          :path        => @data['path'],
          :kind        => 'frontend',
          :time        => @time,
          :environment => @data['environment'],
          :revision    => Appsignal.agent.revision
        },
        :exception => {
          :exception => @data['name'],
          :message   => @data['message'],
          :backtrace => @data['backtrace']
        },
        :failed => true
      }
    end

    def complete!
      Appsignal.enqueue(self)
    end

  end
end
