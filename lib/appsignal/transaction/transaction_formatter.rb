require 'delegate'

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
      if exception?
        add_exception_to_hash!
        add_tags_to_hash!
      end
      add_events_to_hash! if slow_request?
      hash
    end

    protected

    def default_hash
      {
        :request_id => request_id,
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
        o.delete(:action)
        o.delete(:controller)
        o.delete(:name)
        o[:action] = action
      end
    end

    def add_tags_to_hash!
      hash[:log_entry][:tags] = tags
    end

    def add_exception_to_hash!
      hash[:exception] = {
        :exception => exception.class.name,
        :message => exception.message,
        :backtrace => Rails.backtrace_cleaner.clean(exception.backtrace, nil)
      }
    end

    def add_events_to_hash!
      hash[:events] = events.map(&:to_appsignal_hash)
    end
  end
end
