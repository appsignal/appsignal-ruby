describe Appsignal::Extension, :extension_installation_failure do
  context "when the extension library cannot be loaded" do
    # This test breaks the installation on purpose and is not run by default.
    # See `rake test:failure`. If this test was run, run `rake
    # extension:install` again to fix the extension installation.
    it "prints and logs an error" do
      # ENV var to make sure installation fails on purpurse
      ENV["_TEST_APPSIGNAL_EXTENSION_FAILURE"] = "true"
      `rake extension:install` # Run installation

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
