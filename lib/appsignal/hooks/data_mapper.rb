module Appsignal
  class Hooks
    class DataMapperHook < Appsignal::Hooks::Hook
      register :data_mapper

      def dependencies_present?
        defined?(::DataMapper) &&
        defined?(::DataObjects::Connection)
      end

      def install
        require 'appsignal/integrations/data_mapper'
        ::DataObjects::Connection.send(:include, Appsignal::Hooks::DataMapperLogListener)
      end
    end
  end
end
