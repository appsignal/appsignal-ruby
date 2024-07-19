if DependencyHelper.grape_present?
  describe "Appsignal::Loaders::PadrinoLoader" do
    describe "#on_load" do
      it "ensures the Grape middleware is loaded" do
        load_loader(:grape)

        # Calling this doesn't raise a NameError
        Appsignal::Rack::GrapeMiddleware
      end
    end
  end
end
