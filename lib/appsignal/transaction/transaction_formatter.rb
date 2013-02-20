module Appsignal
  class TransactionFormatter
    extend Forwardable

    def initialize(transaction)
      @transaction = transaction
    end

    def self.regular(transaction)
      TransactionFormatter::RegularRequestFormatter.new(transaction)
    end

    def self.slow(transaction)
      TransactionFormatter::SlowRequestFormatter.new(transaction)
    end

    def self.faulty(transaction)
      TransactionFormatter::FaultyRequestFormatter.new(transaction)
    end

    def to_hash
      {
        :request_id => id,
        :action => action,
        :log_entry => formatted_process_action_event,
        :failed => exception?
      }
    end

    protected

    def_delegators :transaction, :id, :events, :exception, :exception?, :env,
      :request, :process_action_event, :action
    def_delegators :process_action_event, :payload

    attr_reader :transaction

    def formatted_process_action_event
      basic_process_action_event.tap { |hsh| hsh.merge!(formatted_payload) if process_action_event }
    end

    def basic_process_action_event
      {
        :path => request.fullpath,
        :kind => 'http_request'
      }
    end

    def formatted_payload
      sanitized_event_payload(process_action_event).merge(
        {
          :duration => process_action_event.duration,
          :time => process_action_event.time.to_f,
          :end => process_action_event.end.to_f,
          :action => action
        }
      )
    end

    def sanitized_event_payload(event)
      Appsignal::ParamsSanitizer.sanitize(
        Appsignal.event_payload_sanitizer.call(event)
      )
    end

    def filtered_environment
      {}.tap do |out|
        env.each_pair do |key, value|
          out[key] = value if ENV_METHODS.include?(key)
        end
      end
    end

    # Based on what Rails uses + some variables we'd like to show
    ENV_METHODS = %w{ CONTENT_LENGTH AUTH_TYPE GATEWAY_INTERFACE
    PATH_TRANSLATED REMOTE_HOST REMOTE_IDENT REMOTE_USER
    REMOTE_ADDR REQUEST_METHOD SERVER_NAME SERVER_PORT
    SERVER_PROTOCOL

    HTTP_X_REQUEST_START HTTP_X_MIDDLEWARE_START HTTP_X_QUEUE_START
    HTTP_X_QUEUE_TIME HTTP_X_HEROKU_QUEUE_WAIT_TIME
    HTTP_X_APPLICATION_START HTTP_ACCEPT HTTP_ACCEPT_CHARSET
    HTTP_ACCEPT_ENCODING HTTP_ACCEPT_LANGUAGE HTTP_CACHE_CONTROL
    HTTP_CONNECTION HTTP_USER_AGENT HTTP_FROM HTTP_NEGOTIATE
    HTTP_PRAGMA HTTP_REFERER }.freeze

  end
end

require 'appsignal/transaction/regular_request_formatter'
require 'appsignal/transaction/slow_request_formatter'
require 'appsignal/transaction/faulty_request_formatter'
require 'appsignal/transaction/params_sanitizer'
