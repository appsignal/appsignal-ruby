require 'json'

module Appsignal
  class Agent
    class Aggregator
      attr_reader :transactions, :event_details, :measurements

      def initialize
        @transactions  = []
        @event_details = []
        @measurements  = {}
      end

      def add_transaction(transaction)
        @transactions << transaction
      end

      def add_event_details(digest, name, title, body)
        @event_details << {
          :digest  => digest,
          :name    => name,
          :title   => title,
          :body    => body
        }
      end

      def add_measurement(digest, name, timestamp, values)
        key       = "#{digest}_#{name}"
        t         = rounded_timestamp(timestamp)
        m_for_t   = @measurements[t] || {}
        v_for_key = m_for_t[key] || Hash.new(0.0)

        v_for_key[:digest] = digest
        v_for_key[:name]   = name
        values.each do |k, v|
          v_for_key[k] += v
        end

        m_for_t[key] = v_for_key
        @measurements[t] = m_for_t
        nil
      end

      def rounded_timestamp(timestamp)
        timestamp - (timestamp % 60)
      end

      def any?
        @transactions.any?  ||
        @event_details.any? ||
        @measurements.any?
      end

      def measurements_hash
        {}.tap do |out|
          @measurements.each do |mk, mv|
            out[mk] = mv.map do |k, v|
              v
            end
          end
        end
      end

      def to_json
        JSON.fast_generate(
          :transactions  => @transactions,
          :event_details => @event_details,
          :measurements  => measurements_hash,
        )
      end
    end
  end
end
