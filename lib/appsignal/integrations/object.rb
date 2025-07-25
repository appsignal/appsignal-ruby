# frozen_string_literal: true

Appsignal::Environment.report_enabled("object_instrumentation") if defined?(Appsignal)

# Extensions to Object for AppSignal method instrumentation.
#
# @see https://docs.appsignal.com/ruby/instrumentation/method-instrumentation.html
#   Method instrumentation documentation.
class Object
  # Instruments a class method with AppSignal monitoring.
  #
  # @param method_name [Symbol] The name of the class method to instrument.
  # @param options [Hash<Symbol, String>] Options for instrumentation.
  # @option options [String] :name Custom event name for the instrumentation.
  # @return [Symbol]
  # @see https://docs.appsignal.com/ruby/instrumentation/method-instrumentation.html
  #   Method instrumentation documentation.
  def self.appsignal_instrument_class_method(method_name, options = {})
    singleton_class.send \
      :alias_method, "appsignal_uninstrumented_#{method_name}", method_name
    singleton_class.send(:define_method, method_name) do |*args, &block|
      name = options.fetch(:name) do
        "#{method_name}.class_method.#{appsignal_reverse_class_name}.other"
      end
      Appsignal.instrument name do
        send "appsignal_uninstrumented_#{method_name}", *args, &block
      end
    end

    if singleton_class.respond_to?(:ruby2_keywords, true) # rubocop:disable Style/GuardClause
      singleton_class.send(:ruby2_keywords, method_name)
    end
  end

  # Instruments an instance method with AppSignal monitoring.
  #
  # @param method_name [Symbol] The name of the instance method to instrument.
  # @param options [Hash<Symbol, String>] Options for instrumentation.
  # @option options [String] :name Custom event name for the instrumentation.
  # @return [Symbol]
  # @see https://docs.appsignal.com/ruby/instrumentation/method-instrumentation.html
  #   Method instrumentation documentation.
  def self.appsignal_instrument_method(method_name, options = {})
    alias_method "appsignal_uninstrumented_#{method_name}", method_name
    define_method method_name do |*args, &block|
      name = options.fetch(:name) do
        "#{method_name}.#{appsignal_reverse_class_name}.other"
      end
      Appsignal.instrument name do
        send "appsignal_uninstrumented_#{method_name}", *args, &block
      end
    end
    ruby2_keywords method_name if respond_to?(:ruby2_keywords, true)
  end

  # @!visibility private
  def self.appsignal_reverse_class_name
    return "AnonymousClass" unless name

    name.split("::").reverse.join(".")
  end

  # @!visibility private
  def appsignal_reverse_class_name
    self.class.appsignal_reverse_class_name
  end
end
