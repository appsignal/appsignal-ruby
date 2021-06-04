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

  describe ".agent_platform" do
    let(:os) { "linux-gnu" }
    let(:ldd_output) { "" }
    before do
      allow(described_class).to receive(:ldd_version_output).and_return(ldd_output)
      allow(RbConfig::CONFIG).to receive(:[])
      allow(RbConfig::CONFIG).to receive(:[]).with("host_os").and_return(os)
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

    context "when using the APPSIGNAL_BUILD_FOR_LINUX_ARM env var" do
      it "returns the linux build" do
        ENV["APPSIGNAL_BUILD_FOR_LINUX_ARM"] = "1"
        is_expected.to eq("linux")
        ENV.delete("APPSIGNAL_BUILD_FOR_LINUX_ARM")
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
      let(:os) { "darwin16.7.0" }
      let(:ldd_output) { "ldd: command not found" }

      it "returns the darwin build" do
        is_expected.to eq("darwin")
      end
    end

    context "when on FreeBSD" do
      let(:os) { "freebsd11" }
      let(:ldd_output) { "ldd: illegal option -- -" }

      it "returns the FreeBSD build" do
        is_expected.to eq("freebsd")
      end
    end
  end

  describe ".agent_architecture" do
    let(:architecture) { "x86_64" }
    let(:ldd_output) { "" }
    before do
      allow(RbConfig::CONFIG).to receive(:[])
      allow(RbConfig::CONFIG).to receive(:[]).with("host_cpu").and_return(architecture)
    end
    subject { described_class.agent_architecture }

    it "returns the host CPU value" do
      is_expected.to eq(architecture)
    end

    context "when using the APPSIGNAL_BUILD_FOR_LINUX_ARM env var" do
      it "returns ARM 64 bit" do
        ENV["APPSIGNAL_BUILD_FOR_LINUX_ARM"] = "1"
        is_expected.to eq("aarch64")
        ENV.delete("APPSIGNAL_BUILD_FOR_LINUX_ARM")
      end
    end
  end
end
