if DependencyHelper.padrino_present?
  describe "Sinatra integration" do
    it "loads the Sinatra loader" do
      ENV["APPSIGNAL_APP_NAME"] = "test/sinatra"
      ENV["APPSIGNAL_PUSH_API_KEY"] = "test-key"

      require "appsignal/integrations/sinatra"

      expect(Appsignal::Loaders.instances).to include(
        :sinatra => kind_of(Appsignal::Loaders::SinatraLoader)
      )
      expect(Appsignal.active?).to be(true)
    end
  end
end
