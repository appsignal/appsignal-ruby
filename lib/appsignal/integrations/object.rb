class Object
  def self.appsignal_instrument_class_method(method_name)
    singleton_class.send \
      :alias_method, "appsignal_uninstrumented_#{method_name}", method_name
    singleton_class.send(:define_method, method_name) do |*args|
      Appsignal.instrument(method_name.to_s) do
        send "appsignal_uninstrumented_#{method_name}", *args
      end
    end
  end

  def self.appsignal_instrument_method(method_name)
    alias_method "appsignal_uninstrumented_#{method_name}", method_name
    define_method method_name do |*args|
      Appsignal.instrument(method_name.to_s) do
        send "appsignal_uninstrumented_#{method_name}", *args
      end
    end
  end
end
