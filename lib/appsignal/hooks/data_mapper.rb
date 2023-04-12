# frozen_string_literal: true

module Appsignal
  class Hooks
    # @api private
    class DataMapperHook < Appsignal::Hooks::Hook
      register :data_mapper

      def dependencies_present?
        defined?(::DataMapper) &&
          defined?(::DataObjects::Connection)
      end

      def install
        require "appsignal/integrations/data_mapper"
        ::DataObjects::Connection.include Appsignal::Hooks::DataMapperLogListener
      end
    end
  end
end
