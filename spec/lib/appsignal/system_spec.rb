require "appsignal/system"

describe Appsignal::System do
  describe ".heroku?" do
    subject { described_class.heroku? }

    context "when on Heroku" do
      around { |example| recognize_as_heroku { example.run } }

      it "returns true" do
        is_expected.to eq(true)
      end
    end

    context "when not on Heroku" do
      it "returns false" do
        is_expected.to eq(false)
      end
    end
  end

  describe ".installed_agent_platform" do
    let(:const_name) { "GEM_EXT_PATH".freeze }
    let(:tmp_ext_dir) { File.join(tmp_dir, "ext") }
    let(:platform_file) { File.join(Appsignal::System::GEM_EXT_PATH, "appsignal.platform") }
    around do |example|
      original_gem_ext_path = Appsignal::System.const_get(const_name)
      Appsignal::System.send(:remove_const, const_name)
      Appsignal::System.const_set(const_name, tmp_ext_dir)
      example.run
      Appsignal::System.send(:remove_const, const_name)
      Appsignal::System.const_set(const_name, original_gem_ext_path)
    end
    after { FileUtils.rm_rf(tmp_ext_dir) }
    subject { described_class.installed_agent_platform }

    context "with an ext/appsignal.platform file" do
      before do
        FileUtils.mkdir_p(Appsignal::System::GEM_EXT_PATH)
        File.open(platform_file, "w") do |file|
          file.write "foo"
        end
      end

      it "returns the contents of the file" do
        expect(subject).to eq("foo")
      end
    end

    context "without an ext/appsignal.platform file" do
      it "returns nil" do
        expect(subject).to be_nil
      end
    end
  end

  describe ".agent_platform" do
    let(:os) { "linux" }
    let(:ldd_output) { "" }
    before do
      allow(described_class).to receive(:ldd_version_output).and_return(ldd_output)
      allow(Gem::Platform.local).to receive(:os).and_return(os)
    end
    subject { described_class.agent_platform }

    context "when the system detection doesn't work" do
      it "returns the libc build" do
        is_expected.to eq("linux")
      end
    end

    context "when using the APPSIGNAL_BUILD_FOR_MUSL env var" do
      it "returns the musl build" do
        ENV["APPSIGNAL_BUILD_FOR_MUSL"] = "1"
        is_expected.to eq("linux-musl")
        ENV.delete("APPSIGNAL_BUILD_FOR_MUSL")
      end
    end

    context "when on a musl system" do
      let(:ldd_output) { "musl libc (x86_64)\nVersion 1.1.16" }

      it "returns the musl build" do
        is_expected.to eq("linux-musl")
      end
    end

    context "when on a libc system" do
      let(:ldd_output) { "ldd (Debian GLIBC 2.15-18+deb8u7) 2.15" }

      it "returns the libc build" do
        is_expected.to eq("linux")
      end

      context "when on an old libc system" do
        let(:ldd_output) { "ldd (Debian GLIBC 2.14-18+deb8u7) 2.14" }

        it "returns the musl build" do
          is_expected.to eq("linux-musl")
        end
      end

      context "when on a very old libc system" do
        let(:ldd_output) { "ldd (Debian GLIBC 2.5-18+deb8u7) 2.5" }

        it "returns the musl build" do
          is_expected.to eq("linux-musl")
        end
      end
    end

    context "when on macOS" do
      let(:os) { "darwin" }
      let(:ldd_output) { "ldd: command not found" }

      it "returns the darwin build" do
        is_expected.to eq("darwin")
      end
    end

    context "when on FreeBSD" do
      let(:os) { "freebsd" }
      let(:ldd_output) { "ldd: illegal option -- -" }

      it "returns the darwin build" do
        is_expected.to eq("freebsd")
      end
    end
  end
end
