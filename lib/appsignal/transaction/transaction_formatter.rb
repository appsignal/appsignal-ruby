require 'forwardable'

module Appsignal
  class TransactionFormatter < SimpleDelegator
    def initialize(transaction)
      super(transaction)
    end

    def hash
      @hash ||= default_hash
    end

    def to_hash
      merge_process_action_event_with_log_entry! if process_action_event
      add_exception_to_hash! if exception?
      add_events_to_hash! if slow_request?
      hash
    end

    protected

    def default_hash
      {
        :request_id => id,
        :log_entry => {
          :path => fullpath,
          :kind => 'http_request',
          :time => time,
          :environment => sanitized_environment,
          :session_data => sanitized_session_data
        },
        :failed => exception?
      }
    end

    def merge_process_action_event_with_log_entry!
      hash[:log_entry].merge!(process_action_event.to_appsignal_hash)
      hash[:log_entry].tap do |o|
        o.merge!(o.delete(:payload))
        o[:action] = "#{o.delete(:controller)}##{o.delete(:action)}"
        o.delete(:name)
      end
    end

    def add_exception_to_hash!
      hash[:exception] = {
        :backtrace => exception.backtrace,
        :exception => exception.name,
        :message => exception.message
      }
    end

    def add_events_to_hash!
      hash[:events] = events.map(&:to_appsignal_hash)
    end
  end
end
