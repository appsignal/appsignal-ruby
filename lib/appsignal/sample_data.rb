# frozen_string_literal: true

module Appsignal
  # @api private
  class SampleData
    def initialize(key, accepted_type = nil)
      @key = key
      @accepted_type = accepted_type
      @blocks = []
      @empty = false
    end

    def add(data = nil, &block)
      @empty = false
      if block_given?
        @blocks << block
      elsif accepted_type?(data)
        @blocks << data
      else
        log_unsupported_data_type(data)
      end
    end

    # @api private
    def set_empty_value!
      @empty = true
      @blocks.clear
    end

    def value
      value = UNSET_VALUE
      @blocks.map! do |block_or_value|
        new_value =
          if block_or_value.respond_to?(:call)
            block_or_value.call
          else
            block_or_value
          end
        unless accepted_type?(new_value)
          log_unsupported_data_type(new_value)
          next
        end

        value = merge_values(value, new_value)
        new_value
      end

      value
    end

    def value?
      @blocks.any?
    end

    # @api private
    def empty?
      @empty
    end

    protected

    attr_reader :blocks

    private

    UNSET_VALUE = nil

    # Method called by `dup` and `clone` to create a duplicate instance.
    # Make sure the `@blocks` variable is also properly duplicated.
    def initialize_copy(original)
      super

      @blocks = original.blocks.dup
    end

    def accepted_type?(value)
      if @accepted_type
        value.is_a?(@accepted_type)
      else
        value.is_a?(Hash) || value.is_a?(Array)
      end
    end

    def merge_values(value_original, value_new)
      unless value_new.instance_of?(value_original.class)
        unless value_original == UNSET_VALUE
          Appsignal.internal_logger.warn(
            "The sample data '#{@key}' changed type from " \
              "'#{value_original.class}' to '#{value_new.class}'. " \
              "These types can not be merged. Using new '#{value_new.class}' type."
          )
        end
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
