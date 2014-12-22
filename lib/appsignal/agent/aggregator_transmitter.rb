module Appsignal
  class Agent
    class AggregatorTransmitter
      AGGREGATOR_LIMIT = 5 # Five minutes with a sleep time of 60 seconds

      attr_reader :agent, :aggregators, :transmitter

      def initialize(agent)
        @agent       = agent
        @aggregators = []
        @transmitter = Appsignal::Transmitter.new('collect')
      end

      def add(aggregator)
        @aggregators.unshift(aggregator)
      end

      def transmit
        @aggregators.map! do |aggregator|
          begin
            if handle_result(transmitter.transmit(aggregator.to_hash))
              nil
            else
              aggregator
            end
          rescue *Transmitter::HTTP_ERRORS => ex
            Appsignal.logger.error "#{ex} while sending aggregators"
            aggregator
          end
        end.compact!
      end

      def truncate(limit = AGGREGATOR_LIMIT)
        return unless @aggregators.length > limit
        Appsignal.logger.error "Aggregator queue to large, removing items"
        @aggregators = @aggregators.first(limit)
      end

      def any?
        @aggregators.any?
      end

      protected

        def handle_result(code)
          Appsignal.logger.debug "Queue sent, response code: #{code}"
          case code.to_i
          when 200 # ok
            true
          when 420 # Enhance Your Calm
            Appsignal.logger.info 'Increasing sleep time since the server told us to'
            agent.sleep_time = agent.sleep_time * 1.5
            true
          when 413 # Request Entity Too Large
            Appsignal.logger.info 'Decreasing sleep time since our last push was too large'
            agent.sleep_time = agent.sleep_time / 1.5
            true
          when 429
            Appsignal.logger.error 'Too many requests sent'
            agent.shutdown(false, 429)
            true
          when 406
            Appsignal.logger.error 'Your appsignal gem cannot communicate with the API anymore, please upgrade.'
            agent.shutdown(false, 406)
            true
          when 402
            Appsignal.logger.error 'Payment required'
            agent.shutdown(false, 402)
            true
          when 401
            Appsignal.logger.error 'API token cannot be authorized'
            agent.shutdown(false, 401)
            true
          else
            Appsignal.logger.error "Unknown Appsignal response code: '#{code}'"
            false
          end
        end
    end
  end
end
