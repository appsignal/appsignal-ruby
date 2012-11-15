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
        :log_entry => formatted_log_entry,
        :failed => exception?
      }
    end

    protected

    def_delegators :transaction, :id, :events, :exception, :exception?, :env,
      :request, :hostname, :log_entry
    def_delegators :log_entry, :payload

    attr_reader :transaction

    def action
      "#{payload[:controller]}##{payload[:action]}"
    end

    def formatted_log_entry
      basic_log_entry.tap { |hsh| hsh.merge!(formatted_payload) if log_entry }
    end

    def basic_log_entry
      {
        :path => request.fullpath,
        :hostname => hostname,
        :kind => 'http_request'
      }
    end

    def formatted_payload
      sanitized_event_payload(log_entry).merge(
        {
          :duration => log_entry.duration,
          :time => log_entry.time.to_f,
          :end => log_entry.end.to_f,
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

    HTTP_ACCEPT HTTP_ACCEPT_CHARSET HTTP_ACCEPT_ENCODING
    HTTP_ACCEPT_LANGUAGE HTTP_CACHE_CONTROL HTTP_CONNECTION
    HTTP_USER_AGENT HTTP_FROM HTTP_NEGOTIATE HTTP_PRAGMA
    HTTP_REFERER}.freeze

  end
end

require 'appsignal/transaction/regular_request_formatter'
require 'appsignal/transaction/slow_request_formatter'
require 'appsignal/transaction/faulty_request_formatter'
require 'appsignal/transaction/params_sanitizer'
