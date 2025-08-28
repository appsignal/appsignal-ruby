if DependencyHelper.sinatra_present?
  describe "Appsignal::Loaders::SinatraLoader" do
    describe "#on_load" do
      it "registers Sinatra default config" do
        ::Sinatra::Application.settings.root = "/some/path"
        load_loader(:sinatra)

        expect(Appsignal::Config.loader_defaults).to include(
          :name => :sinatra,
          :root_path => "/some/path",
          :env => :test,
          :options => {}
        )
      end
    end

    describe "#on_start" do
      after { uninstall_sinatra_integration }

      def uninstall_sinatra_integration
        expected_middleware = [
          Appsignal::Rack::EventMiddleware,
          Appsignal::Rack::SinatraBaseInstrumentation
        ]
        Sinatra::Base.instance_variable_get(:@middleware).delete_if do |middleware|
          expected_middleware.include?(middleware.first)
        end
      end

      it "adds the instrumentation middleware to Sinatra::Base" do
        load_loader(:sinatra)
        start_loader(:sinatra)

        middlewares = Sinatra::Base.middleware.to_a
        expect(middlewares).to include(
          [Appsignal::Rack::EventMiddleware, [], nil]
        )
        expect(middlewares).to include(
          [Appsignal::Rack::SinatraBaseInstrumentation, [], nil]
        )
      end
    end
  end
end
