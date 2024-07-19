if DependencyHelper.padrino_present?
  describe "Padrino integration" do
    it "loads the Padrino loader" do
      ENV["APPSIGNAL_APP_NAME"] = "test/sinatra"
      ENV["APPSIGNAL_PUSH_API_KEY"] = "test-key"

      require "appsignal/integrations/padrino"

      expect(Appsignal::Loaders.instances).to include(
        :padrino => kind_of(Appsignal::Loaders::PadrinoLoader)
      )
      expect(Appsignal.active?).to be(true)
    end
  end
end
