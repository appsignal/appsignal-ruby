# frozen_string_literal: true

require "digest"
require "fileutils"
require "open-uri"
require "zlib"
require "json"
require "rubygems/package"
require File.expand_path("../lib/appsignal/version.rb", __dir__)
require File.expand_path("../lib/appsignal/system.rb", __dir__)
require_relative "./agent"

EXT_PATH = File.expand_path(__dir__).freeze

AGENT_PLATFORM = Appsignal::System.agent_platform
AGENT_ARCHITECTURE = Appsignal::System.agent_architecture
TARGET_TRIPLE = "#{AGENT_ARCHITECTURE}-#{AGENT_PLATFORM}"
ARCH_CONFIG = APPSIGNAL_AGENT_CONFIG["triples"][TARGET_TRIPLE].freeze
CA_CERT_PATH = File.join(EXT_PATH, "../resources/cacert.pem").freeze

def ext_path(path)
  File.join(EXT_PATH, path)
end

def report
  @report ||=
    begin
      rbconfig = RbConfig::CONFIG
      patchlevel = rbconfig["PATCHLEVEL"]
      patchlevel_label = "-p#{patchlevel}" if patchlevel
      ruby_version = "#{RUBY_VERSION}#{patchlevel_label}"
      {
        "result" => {
          "status" => "incomplete"
        },
        "language" => {
          "name" => "ruby",
          "version" => ruby_version
        },
        "download" => {
          "checksum" => "unverified"
        },
        "build" => {
          "time" => Time.now.utc,
          "package_path" => File.dirname(EXT_PATH),
          "architecture" => AGENT_ARCHITECTURE,
          "target" => AGENT_PLATFORM,
          "musl_override" => Appsignal::System.force_musl_build?,
          "linux_arm_override" => Appsignal::System.force_linux_arm_build?,
          "dependencies" => {},
          "flags" => {}
        },
        "host" => {
          "root_user" => Process.uid.zero?,
          "dependencies" => {}.tap do |d|
            ldd_output = Appsignal::System.ldd_version_output
            ldd_version = Appsignal::System.extract_ldd_version(ldd_output)
            d["libc"] = ldd_version if ldd_version
          end
        }
      }.tap do |r|
        proxy, error = http_proxy
        r["download"]["http_proxy"] = proxy
        r["download"]["http_proxy_error"] = error if error
      end
    end
end

def write_report
  File.write(File.join(EXT_PATH, "install.report"), JSON.generate(report))
end

def create_dummy_makefile
  File.write(File.join(EXT_PATH, "Makefile"), "default:\nclean:\ninstall:")
end

def successful_installation
  report["result"] = { "status" => "success" }
end

def abort_installation(reason)
  report["result"] = {
    "status" => "failed",
    "message" => reason
  }
  false
end

def fail_installation_with_error(error)
  report["result"] = {
    "status" => "error",
    "error" => "#{error.class}: #{error}",
    "backtrace" => error.backtrace
  }
  false
end

def installation_succeeded?
  report["result"]["status"] == "success"
end

def check_architecture
  if APPSIGNAL_AGENT_CONFIG["triples"].key?(TARGET_TRIPLE)
    true
  else
    abort_installation(
      "AppSignal currently does not support your system architecture (#{TARGET_TRIPLE})." \
        "Please let us know at support@appsignal.com, we aim to support everything " \
        "our customers run."
    )
  end
end

def download_archive(type)
  report["build"]["source"] = "remote"

  unless ARCH_CONFIG.key?(type)
    abort_installation(
      "AppSignal currently does not support your system. " \
        "Expected config for architecture '#{TARGET_TRIPLE}' and package type '#{type}', " \
        "but none found. For a full list of supported systems visit: " \
        "https://docs.appsignal.com/support/operating-systems.html"
    )
    return
  end

  version = APPSIGNAL_AGENT_CONFIG["version"]
  filename = ARCH_CONFIG[type]["filename"]
  download_errors = []

  APPSIGNAL_AGENT_CONFIG["mirrors"].each do |mirror|
    download_url = [mirror, version, filename].join("/")
    report["download"]["download_url"] = download_url

    begin
      proxy, _error = http_proxy
      args = [
        download_url,
        { :ssl_ca_cert => CA_CERT_PATH,
          :proxy => proxy }
      ]
      if URI.respond_to?(:open) # rubocop:disable Style/GuardClause
        return URI.open(*args)
      else
        return open(*args)
      end
    rescue => error
      download_errors << "- URL: #{download_url}\n  Error: #{error.class}: #{error.message}"
      next
    end
  end

  abort_installation(
    "Could not download archive from any of our mirrors. " \
      "Please make sure your network allows access to any of these mirrors.\n" \
      "Attempted to download the archive from the following urls:\n#{download_errors.join("\n")}"
  )
end

def verify_archive(archive, type)
  expected_checksum = ARCH_CONFIG[type]["checksum"]
  actual_checksum = Digest::SHA256.hexdigest(archive.read)
  if actual_checksum == expected_checksum
    report["download"]["checksum"] = "verified"
    true
  else
    report["download"]["checksum"] = "invalid"
    abort_installation(
      "Checksum of downloaded archive could not be verified: " \
        "Expected '#{expected_checksum}', got '#{actual_checksum}'."
    )
  end
end

def unarchive(archive)
  Gem::Package::TarReader.new(Zlib::GzipReader.open(archive)) do |tar|
    tar.each do |entry|
      next unless entry.file?

      File.binwrite(ext_path(entry.full_name), entry.read)
    end
  end
  store_download_version_on_report
  FileUtils.chmod(0o755, ext_path("appsignal-agent"))
end

def store_download_version_on_report
  path = File.expand_path(File.join(File.dirname(__FILE__), "appsignal.version"))
  report["build"]["agent_version"] = File.read(path).strip
end

def http_proxy
  proxy, error =
    begin
      [try_http_proxy_value(Gem.configuration[:http_proxy]), nil]
    rescue => error
      # Ignore this setting if the `.gemrc` file can't be read. This raises an
      # error on Rubies with psych 4 in the standard library, but also have
      # psych 5 installed: Ruby < 3.2.
      # https://github.com/appsignal/appsignal-ruby/issues/904
      [nil, error]
    end
  return [proxy, error] if proxy

  proxy = try_http_proxy_value(ENV.fetch("http_proxy", nil))
  return [proxy, error] if proxy

  proxy = try_http_proxy_value(ENV.fetch("HTTP_PROXY", nil))
  return [proxy, error] if proxy

  [nil, error]
end

def try_http_proxy_value(value)
  value if value.respond_to?(:empty?) && !value.strip.empty?
end

# Fail the installation on purpose in a specific test environment.
def fail_install_on_purpose_in_test!
  return unless ENV["_TEST_APPSIGNAL_EXTENSION_FAILURE"]

  raise "AppSignal internal test failure"
end
