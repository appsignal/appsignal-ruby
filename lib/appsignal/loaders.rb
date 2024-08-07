# frozen_string_literal: true

module Appsignal
  # @api private
  module Loaders
    class << self
      def loaders
        @loaders ||= {}
      end

      def instances
        @instances ||= {}
      end

      def register(name, klass)
        loaders[name.to_sym] = klass
      end

      def registered?(name)
        loaders.key?(name)
      end

      def unregister(name)
        loaders.delete(name)
      end

      def load(name_str)
        name = name_str.to_sym

        unless registered?(name)
          require_loader(name)
          unless registered?(name)
            Appsignal.internal_logger
              .warn("No loader found with the name '#{name}'.")
            return
          end
        end

        Appsignal.internal_logger.debug("Loading '#{name}' loader")

        begin
          loader_klass = loaders[name]
          loader = loader_klass.new
          instances[name] = loader
          loader.on_load if loader.respond_to?(:on_load)
        rescue => e
          Appsignal.internal_logger.error(
            "An error occurred while loading the '#{name}' loader: " \
              "#{e.class}: #{e.message}\n#{e.backtrace}"
          )
        end
      end

      def start
        instances.each do |name, instance|
          Appsignal.internal_logger.debug("Starting '#{name}' loader")
          begin
            instance.on_start if instance.respond_to?(:on_start)
          rescue => e
            Appsignal.internal_logger.error(
              "An error occurred while starting the '#{name}' loader: " \
                "#{e.class}: #{e.message}\n#{e.backtrace.join("\n")}"
            )
          end
        end
      end

      private

      def require_loader(name)
        require "appsignal/loaders/#{name}"
      rescue LoadError
        nil
      end
    end

    class Loader
      class << self
        attr_reader :loader_name

        def register(name)
          @loader_name = name
          Loaders.register(name, self)
        end
      end

      def register_config_defaults(options)
        Appsignal::Config.add_loader_defaults(self.class.loader_name, **options)
      end
    end
  end
end
