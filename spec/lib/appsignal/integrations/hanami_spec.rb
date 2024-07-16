# frozen_string_literal: true

if DependencyHelper.hanami_present?
  describe "Hanami integration" do
    it "loads the Hanami loader" do
      ENV["APPSIGNAL_APP_NAME"] = "test/sinatra"
      ENV["APPSIGNAL_PUSH_API_KEY"] = "test-key"

      require "appsignal/integrations/hanami"

      expect(Appsignal::Loaders.instances).to include(
        :hanami => kind_of(Appsignal::Loaders::HanamiLoader)
      )
      expect(Appsignal.active?).to be(true)
    end
  end
end
