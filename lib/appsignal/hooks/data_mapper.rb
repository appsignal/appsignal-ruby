module Appsignal
  class Hooks
    # @api private
    class DataMapperHook < Appsignal::Hooks::Hook
      def dependencies_present?
        defined?(::DataMapper) &&
          defined?(::DataObjects::Connection)
      end

      def install
        require "appsignal/integrations/data_mapper"
        ::DataObjects::Connection.send(:include, Appsignal::Hooks::DataMapperLogListener)
      end
    end
  end
end

Appsignal::Hooks.register(:data_mapper, Appsignal::Hooks::DataMapperHook)
