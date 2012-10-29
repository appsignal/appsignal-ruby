require 'socket'

module Appsignal
  class Transaction
    def self.create(key, env)
      Thread.current[:appsignal_transaction_id] = key
      Appsignal.transactions[key] = Appsignal::Transaction.new(key, env)
    end

    def self.current
      Appsignal.transactions[Thread.current[:appsignal_transaction_id]]
    end

    attr_reader :id, :events, :exception, :env, :log_entry

    def initialize(id, env)
      @id = id
      @events = []
      @log_entry = nil
      @exception = nil
      @env = env
    end

    def request
      ActionDispatch::Request.new(@env)
    end

    def set_log_entry(event)
      @log_entry = event
    end

    def add_event(event)
      @events << event
    end

    def add_exception(ex)
      @exception = ex
    end

    def exception?
      !! @exception
    end

    def formatted_exception
      return {} unless exception?
      {
        :backtrace => @exception.backtrace,
        :exception => @exception.name,
        :message => @exception.message
      }
    end

    def format(event)
      {
        :name => event.name,
        :duration => event.duration,
        :time => event.time,
        :end => event.end,
      }
    end

    def detailed_events
      @events.map do |event|
        format(event).merge(
          :payload => sanitized_event_payload(event)
        )
      end
    end

    def sanitized_event_payload(event)
      Appsignal.event_payload_sanitizer.call(event)
    end

    def filtered_environment
      out = {}
      @env.each_pair do |key, value|
        if ENV_METHODS.include?(key)
          out[key] = value
        end
      end
      out
    end

    def hostname
      @hostname ||= Socket.gethostname
    end

    def formatted_log_entry
      {
        :path => request.fullpath,
        :hostname => hostname,
        :environment => filtered_environment,
        :session_data => request.session,
        :kind => 'http_request'
      }.merge(formatted_payload)
    end

    def formatted_payload
      if @log_entry
        {
          :duration => @log_entry.duration,
          :time => @log_entry.time,
          :end => @log_entry.end
        }.merge(sanitized_event_payload(@log_entry)).tap do |o|
          o[:action] = "#{@log_entry.payload[:controller]}"\
            "##{@log_entry.payload[:action]}"
        end
      else
        if exception?
          {:action => @exception.inspect.gsub(/^<#(.*)>$/, '\1')}
        else
          {}
        end
      end
    end

    def slow_request?
      return false unless @log_entry
      @log_entry.duration >= Appsignal.config[:slow_request_threshold]
    end

    def to_hash
      {
        :request_id => @id,
        :log_entry => formatted_log_entry,
        :events => slow_request? ? detailed_events : [],
        :exception => formatted_exception,
        :failed => exception.present?
      }
    end

    def complete!
      Thread.current[:appsignal_transaction_id] = nil
      current_transaction = Appsignal.transactions.delete(@id)
      if @log_entry || exception?
        Appsignal.agent.add_to_queue(current_transaction.to_hash)
      end
    end
  end

  # Based on what Rails uses + some variables we'd like to show
  ENV_METHODS = %w[ CONTENT_LENGTH AUTH_TYPE GATEWAY_INTERFACE
    PATH_TRANSLATED REMOTE_HOST REMOTE_IDENT REMOTE_USER
    REMOTE_ADDR REQUEST_METHOD SERVER_NAME SERVER_PORT
    SERVER_PROTOCOL

    HTTP_ACCEPT HTTP_ACCEPT_CHARSET HTTP_ACCEPT_ENCODING
    HTTP_ACCEPT_LANGUAGE HTTP_CACHE_CONTROL HTTP_CONNECTION
    HTTP_USER_AGENT HTTP_FROM HTTP_NEGOTIATE HTTP_PRAGMA ].freeze
end
