module Appsignal
  class JSExceptionTransaction
    attr_reader :uuid, :ext

    def initialize(data)
      @data = data
      @uuid = SecureRandom.uuid
      @ext = Appsignal::Extension.start_transaction(@uuid, Appsignal::Transaction::FRONTEND)

      set_action
      set_metadata
      set_error
      set_sample_data
    end

    def set_action
      @ext.set_action(@data['action'])
    end

    def set_metadata
      @ext.set_metadata(
        'path', @data['path']
      ) if @data['path']
    end

    def set_error
      @ext.set_error(
        @data['name'],
        @data['message'],
        Appsignal::Utils.json_generate(@data['backtrace'])
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
          @ext.set_sample_data(
            key.to_s,
            Appsignal::Utils.json_generate(data)
          )
        rescue JSON::GeneratorError=>e
          Appsignal.logger.error("JSON generate error (#{e.message}) for '#{data.inspect}'")
        end
      end
    end

    def complete!
      @ext.finish
      @ext.complete
    end
  end
end
