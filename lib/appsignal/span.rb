# frozen_string_literal: true

module Appsignal
  class Span
    def initialize(namespace = nil, ext = nil)
      @ext = ext || Appsignal::Extension::Span.root(namespace || "")
    end

    def child
      Span.new(nil, @ext.child)
    end

    def name=(value)
      @ext.set_name(value)
    end

    def add_error(error)
      unless error.is_a?(Exception)
        Appsignal.logger.error "Appsignal::Span#add_error: Cannot add error. " \
          "The given value is not an exception: #{error.inspect}"
        return
      end
      return unless error

      backtrace = cleaned_backtrace(error.backtrace)
      @ext.add_error(
        error.class.name,
        error.message.to_s,
        backtrace ? Appsignal::Utils::Data.generate(backtrace) : Appsignal::Extension.data_array_new
      )
    end

    def set_sample_data(key, data)
      return unless key && data && (data.is_a?(Array) || data.is_a?(Hash))

      @ext.set_sample_data(
        key.to_s,
        Appsignal::Utils::Data.generate(data)
      )
    end

    def []=(key, value)
      case value
      when String
        @ext.set_attribute_string(key.to_s, value)
      when Integer
        begin
          @ext.set_attribute_int(key.to_s, value)
        rescue RangeError
          @ext.set_attribute_string(key.to_s, "bigint:#{value}")
        end
      when TrueClass, FalseClass
        @ext.set_attribute_bool(key.to_s, value)
      when Float
        @ext.set_attribute_double(key.to_s, value)
      else
        raise TypeError, "value needs to be a string, int, bool or float"
      end
    end

    def to_h
      json = @ext.to_json
      return unless json

      JSON.parse(json)
    end

    def instrument
      yield self
    ensure
      close
    end

    def close
      @ext.close
    end

    def closed?
      to_h.nil?
    end

    private

    def cleaned_backtrace(backtrace)
      if defined?(::Rails) && backtrace
        ::Rails.backtrace_cleaner.clean(backtrace, nil)
      else
        backtrace
      end
    end
  end
end
