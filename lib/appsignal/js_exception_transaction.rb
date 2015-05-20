module Appsignal
  class JSExceptionTransaction

    def initialize(data)
      @data = data
      @uuid = SecureRandom.uuid

      Appsignal::Extension.start_transaction(@uuid)

      set_base_data
      set_metadata
      set_error
      set_error_data
    end

    def set_base_data
      Appsignal::Extension.set_transaction_basedata(
        @uuid,
        'frontend',
        @data['action'],
        0
      )
    end

    def set_metadata
      Appsignal::Extension.set_transaction_metadata(
        @uuid, 'path', @data['path']
      ) if @data['path']
    end

    def set_error
      Appsignal::Extension.set_transaction_error(
        @uuid,
        @data['name'],
        @data['message']
      )
    end

    def set_error_data
      {
        :params       => @data['params'],
        :environment  => @data['environment'],
        :backtrace    => @data['backtrace'],
        :tags         => @data['tags']
      }.each do |key, data|
        next unless data.is_a?(Array) || data.is_a?(Hash)
        begin
          Appsignal::Extension.set_transaction_error_data(
            @uuid,
            key.to_s,
            JSON.generate(data)
          )
        rescue JSON::GeneratorError=>e
          Appsignal.logger.error("JSON generate error (#{e.message}) for '#{data.inspect}'")
        end
      end
    end

    def complete!
      Appsignal::Extension.finish_transaction(@uuid)
    end
  end
end
