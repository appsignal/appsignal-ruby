# frozen_string_literal: true

module Appsignal
  # @api private
  class SampleData
    def initialize(key, accepted_type = nil)
      @key = key
      @accepted_type = accepted_type
      @blocks = []
    end

    def add(data = nil, &block)
      if block_given?
        @blocks << block
      elsif accepted_type?(data)
        @blocks << data
      else
        log_unsupported_data_type(data)
      end
    end

    def value
      value = nil
      @blocks.each_with_index do |block_or_value, index|
        new_value =
          if block_or_value.respond_to?(:call)
            v = block_or_value.call
            @blocks[index] = v
            v
          else
            block_or_value
          end
        unless accepted_type?(new_value)
          log_unsupported_data_type(new_value)
          next
        end

        value = merge_values(value, new_value)
      end

      value
    end

    def value?
      @blocks.any?
    end

    private

    def accepted_type?(value)
      if @accepted_type
        value.is_a?(@accepted_type)
      else
        value.is_a?(Hash) || value.is_a?(Array)
      end
    end

    def merge_values(value_original, value_new)
      unless value_new.instance_of?(value_original.class)
        # TODO: add log warning
        # Value types don't match. The block is leading so overwrite the value
        return value_new
      end

      case value_original
      when Hash
        value_original.merge(value_new)
      when Array
        value_original + value_new
      else
        value_new
      end
    end

    def log_unsupported_data_type(value)
      Appsignal.internal_logger.error(
        "Sample data '#{@key}': Unsupported data type '#{value.class}' received: #{value.inspect}"
      )
    end
  end
end
