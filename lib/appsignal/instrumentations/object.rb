class Object
  def self.measure(method, category_name=nil)
    alias_method "#{method}_unmeasured", method
    define_method method do |*args|
      cat_name = if category_name.respond_to?(:call)
                   self.instance_exec args, &category_name
                 elsif category_name && category_name.respond_to?(:to_s)
                   category_name.to_s
                 else
                   first = args.first
                   if first.respond_to?(:to_s)
                     first.to_s
                   else
                     nil
                   end
                 end

      ActiveSupport::Notifications.instrument(
        "#{self.class.name}.#{method.to_s}",
        :name => cat_name
      ) do
        send "#{method}_unmeasured", *args
      end
    end
  end

  def measure(name, cat = "")
    names = [self.class.name, __method__.to_s.gsub(/:/,''), name.downcase.gsub(/ /, '_')]
    result = nil
    ActiveSupport::Notifications.instrument(names.join('.'), name: cat) do
      result = yield
    end
    result
  end
end
