# frozen_string_literal: true

Appsignal::Environment.report_enabled("object_instrumentation") if defined?(Appsignal)

class Object
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

  def self.appsignal_reverse_class_name
    return "AnonymousClass" unless name

    name.split("::").reverse.join(".")
  end

  def appsignal_reverse_class_name
    self.class.appsignal_reverse_class_name
  end
end
