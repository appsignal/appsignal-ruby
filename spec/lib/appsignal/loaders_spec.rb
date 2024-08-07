describe Appsignal::Loaders do
  describe ".register" do
    before do
      define_loader(:test_loader) do
        def on_load
          puts "do something on_load"
          register_config_defaults(
            :root_path => "/some/path",
            :env => "test env",
            :active => false
          )
        end
      end
    end

    it "registers a loader" do
      define_loader(:test_loader)
      expect(Appsignal::Loaders.loaders).to have_key(:test_loader)
    end
  end

  describe ".unregister" do
    it "unregisters a loader" do
      define_loader(:test_loader)
      expect(Appsignal::Loaders.loaders).to have_key(:test_loader)

      Appsignal::Loaders.unregister(:test_loader)
      expect(Appsignal::Loaders.loaders).to_not have_key(:test_loader)
    end
  end

  describe ".load" do
    it "calls the Loader's on_loader method" do
      Appsignal::Testing.store[:loader_loaded] = 0
      define_loader(:test_loader) do
        def on_load
          Appsignal::Testing.store[:loader_loaded] += 1
        end
      end
      Appsignal::Loaders.load(:test_loader)

      expect(Appsignal::Testing.store[:loader_loaded]).to eq(1)
    end

    it "registers config defaults" do
      define_loader(:test_loader) do
        def on_load
          register_config_defaults(:my_option => true)
        end
      end
      Appsignal::Loaders.load(:test_loader)

      expect(Appsignal::Config.loader_defaults).to eq([
        {
          :name => :test_loader,
          :env => nil,
          :root_path => nil,
          :options => { :my_option => true }
        }
      ])
    end

    it "does not load errors that aren't registered" do
      logs =
        capture_logs do
          Appsignal::Loaders.load(:unknown_loader)
        end

      expect(logs).to contains_log(:warn, "No loader found with the name 'unknown_loader'.")
    end

    it "loads the loader file on load" do
      expect(Appsignal::Loaders.registered?(:loader_stub)).to be_falsy
      Appsignal::Loaders.load(:loader_stub)

      expect(Appsignal::Loaders.registered?(:loader_stub)).to be_truthy
    end

    it "does not error when a loader has no on_load method" do
      define_loader(:test_loader) do
        # Do nothing
      end
      Appsignal::Loaders.load(:test_loader)
    end

    it "logs an error when an error occurs on load" do
      define_loader(:test_loader) do
        def on_load
          raise ExampleStandardError, "uh oh"
        end
      end
      logs =
        capture_logs do
          Appsignal::Loaders.load(:test_loader)
        end

      expect(logs).to contains_log(
        :error,
        "An error occurred while loading the 'test_loader' loader: ExampleStandardError: uh oh"
      )
    end
  end

  describe ".start" do
    it "starts all loaded loaders" do
      Appsignal::Testing.store[:loader_started] = 0
      define_loader(:test_loader) do
        def on_start
          Appsignal::Testing.store[:loader_started] += 1
        end
      end
      Appsignal::Loaders.load(:test_loader)
      Appsignal::Loaders.start

      expect(Appsignal::Testing.store[:loader_started]).to eq(1)
    end

    it "does not error when a loader has no on_start method" do
      define_loader(:test_loader) do
        # Do nothing
      end
      Appsignal::Loaders.load(:test_loader)
      Appsignal::Loaders.start
    end

    it "logs an error when an error occurs on start" do
      define_loader(:test_loader) do
        def on_start
          raise ExampleStandardError, "uh oh"
        end
      end
      logs =
        capture_logs do
          Appsignal::Loaders.load(:test_loader)
          Appsignal::Loaders.start
        end

      expect(logs).to contains_log(
        :error,
        "An error occurred while starting the 'test_loader' loader: ExampleStandardError: uh oh"
      )
    end
  end
end
