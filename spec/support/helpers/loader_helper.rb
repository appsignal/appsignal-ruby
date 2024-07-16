module LoaderHelper
  def load_loader(name)
    Appsignal.load(name)
  end

  def start_loader(name)
    Appsignal::Loaders.instances.fetch(name).on_start
  end

  def unregister_loader(name)
    Appsignal::Loaders.unregister(name)
  end

  def define_loader(name, &block)
    Appsignal::Testing.registered_loaders << name
    Class.new(Appsignal::Loaders::Loader) do
      register name
      class_eval(&block) if block_given?
    end
  end
end
