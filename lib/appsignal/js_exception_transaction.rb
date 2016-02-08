module Appsignal
  class JSExceptionTransaction
    attr_reader :uuid, :transaction_index

    def initialize(data)
      @data = data
      @uuid = SecureRandom.uuid
      @transaction_index = Appsignal::Extension.start_transaction(@uuid, Appsignal::Transaction::FRONTEND)

      set_action
      set_metadata
      set_error
      set_sample_data
    end

    def set_action
      Appsignal::Extension.set_transaction_action(@transaction_index, @data['action'])
    end

    def set_metadata
      Appsignal::Extension.set_transaction_metadata(
        @transaction_index, 'path', @data['path']
      ) if @data['path']
    end

    def set_error
      Appsignal::Extension.set_transaction_error(
        @transaction_index,
        @data['name'],
        @data['message'],
        JSON.generate(@data['backtrace'])
      )
    end

    def set_sample_data
      {
        :params       => @data['params'],
        :environment  => @data['environment'],
        :tags         => @data['tags']
      }.each do |key, data|
        next unless data.is_a?(Array) || data.is_a?(Hash)
        begin
          Appsignal::Extension.set_transaction_sample_data(
            @transaction_index,
            key.to_s,
            JSON.generate(data)
          )
        rescue JSON::GeneratorError=>e
          Appsignal.logger.error("JSON generate error (#{e.message}) for '#{data.inspect}'")
        end
      end
    end

    def complete!
      Appsignal::Extension.finish_transaction(@transaction_index)
      Appsignal::Extension.complete_transaction(@transaction_index)
    end
  end
end
