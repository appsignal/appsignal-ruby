# frozen_string_literal: true

module Appsignal
  class JSExceptionTransaction
    attr_reader :uuid, :ext

    def initialize(data)
      @data = data
      @uuid = SecureRandom.uuid
      @ext = Appsignal::Extension.start_transaction(@uuid, Appsignal::Transaction::FRONTEND, 0)

      set_action
      set_metadata
      set_error
      set_sample_data
    end

    def set_action
      return unless @data["action"]
      ext.set_action(@data["action"])
    end

    def set_metadata
      return unless @data["path"]
      ext.set_metadata("path", @data["path"])
    end

    def set_error
      ext.set_error(
        @data["name"],
        @data["message"] || "",
        Appsignal::Utils.data_generate(@data["backtrace"] || [])
      )
    end

    def set_sample_data
      {
        :params       => @data["params"],
        :session_data => @data["session_data"],
        :environment  => @data["environment"],
        :tags         => @data["tags"]
      }.each do |key, data|
        next unless data.is_a?(Array) || data.is_a?(Hash)
        ext.set_sample_data(
          key.to_s,
          Appsignal::Utils.data_generate(data)
        )
      end
    end

    def complete!
      ext.finish(0)
      ext.complete
    end
  end
end
