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

  describe ".ruby_2_or_up?" do
    around do |example|
      original_ruby_version = RUBY_VERSION
      Object.send(:remove_const, "RUBY_VERSION")
      Object.const_set("RUBY_VERSION", ruby_version)
      example.run
      Object.send(:remove_const, "RUBY_VERSION")
      Object.const_set("RUBY_VERSION", original_ruby_version)
    end
    subject { described_class.ruby_2_or_up? }

    context "when on Ruby 1.9" do
      let(:ruby_version) { "1.9.3-p533" }

      it "returns false" do
        is_expected.to be(false)
      end
    end

    context "when on Ruby 2.0" do
      let(:ruby_version) { "2.0.0" }

      it "returns true" do
        is_expected.to be(true)
      end
    end

    context "when on Ruby 2.x" do
      let(:ruby_version) { "2.1.0" }

      it "returns true" do
        is_expected.to be(true)
      end
    end
  end
end
