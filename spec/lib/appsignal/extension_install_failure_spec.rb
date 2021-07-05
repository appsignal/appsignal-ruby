describe Appsignal::Extension, :extension_installation_failure do
  context "when the extension library cannot be loaded" do
    it "prints and logs an error" do
      require "open3"
      _stdout, stderr, _status = Open3.capture3("bin/appsignal --version")
      expect(stderr).to include("ERROR: AppSignal failed to load extension")
      error_message =
        if DependencyHelper.running_jruby?
          "cannot open shared object file"
        else
          "LoadError: cannot load such file"
        end
      expect(stderr).to include(error_message)
    end
  end
end
