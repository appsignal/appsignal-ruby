require "bundler/cli"
require "bundler/cli/common"
require "appsignal/cli/diagnose/paths"

describe Appsignal::CLI::Diagnose::Paths do
  describe "#paths" do
    before { Appsignal.config = project_fixture_config }

    it "returns gem installation path as package_install_path" do
      expect(described_class.new.paths[:package_install_path]).to eq(
        :label => "AppSignal gem path",
        :path => Bundler::CLI::Common.select_spec("appsignal").full_gem_path.strip
      )
    end
  end
end
