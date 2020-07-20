describe "JRuby extension", :jruby do
  let(:extension) { Appsignal::Extension }
  let(:jruby_module) { Appsignal::Extension::Jruby }

  it "creates a JRuby extension module" do
    expect(Appsignal::Extension::Jruby).to be_kind_of(Module)
  end

  describe "string conversions" do
    it "keeps the same value during string type conversions" do
      # UTF-8 string with NULL
      # Tests if the conversions between the conversions without breaking on
      # NULL terminated strings in C.
      string = "Merry Christmas! \u0000 🎄"

      appsignal_string = extension.make_appsignal_string(string)
      ruby_string = extension.make_ruby_string(appsignal_string)

      expect(ruby_string).to eq("Merry Christmas! \u0000 🎄")
    end
  end

  it "loads libappsignal with FFI" do
    expect(jruby_module.ffi_libraries.map(&:name).first).to include "libappsignal"
  end

  describe ".lib_extension" do
    subject { jruby_module.lib_extension }

    context "when on a darwin system" do
      before { expect(Appsignal::System).to receive(:agent_platform).and_return("darwin") }

      it "returns the extension for darwin" do
        is_expected.to eq "dylib"
      end
    end

    context "when on a linux system" do
      before { expect(Appsignal::System).to receive(:agent_platform).and_return("linux") }

      it "returns the lib extension for linux" do
        is_expected.to eq "so"
      end
    end
  end
end
