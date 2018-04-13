# frozen_string_literal: true

module Appsignal
  class Hooks
    # @api private
    class MongoRubyDriverHook < Appsignal::Hooks::Hook
      register :mongo_ruby_driver

      def dependencies_present?
        defined?(::Mongo::Monitoring::Global)
      end

      def install
        require "appsignal/integrations/mongo_ruby_driver"

        Mongo::Monitoring::Global.subscribe(
          Mongo::Monitoring::COMMAND,
          Appsignal::Hooks::MongoMonitorSubscriber.new
        )
      end
    end
  end
end
