require "digest"
require "fileutils"
require "open-uri"
require "zlib"
require "json"
require "yaml"
require "rubygems/package"
require File.expand_path("../../lib/appsignal/version.rb", __FILE__)
require File.expand_path("../../lib/appsignal/system.rb", __FILE__)

EXT_PATH     = File.expand_path("..", __FILE__).freeze
AGENT_CONFIG = YAML.load(File.read(File.join(EXT_PATH, "agent.yml"))).freeze

AGENT_PLATFORM = Appsignal::System.agent_platform
AGENT_ARCHITECTURE = Appsignal::System.agent_architecture
TARGET_TRIPLE = "#{AGENT_ARCHITECTURE}-#{AGENT_PLATFORM}".freeze
ARCH_CONFIG = AGENT_CONFIG["triples"][TARGET_TRIPLE].freeze
CA_CERT_PATH = File.join(EXT_PATH, "../resources/cacert.pem").freeze

def ext_path(path)
  File.join(EXT_PATH, path)
end

def report
  @report ||=
    begin
      rbconfig = RbConfig::CONFIG
      {
        "result" => {
          "status" => "incomplete"
        },
        "language" => {
          "name" => "ruby",
          "version" => "#{rbconfig["ruby_version"]}-p#{rbconfig["PATCHLEVEL"]}"
        },
        "download" => {
          "checksum" => "unverified",
          "http_proxy" => http_proxy
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
      }
    end
end

def write_report
  File.open(File.join(EXT_PATH, "install.report"), "w") do |file|
    file.write JSON.generate(report)
  end
end

def create_dummy_makefile
  File.open(File.join(EXT_PATH, "Makefile"), "w") do |file|
    file.write "default:\nclean:\ninstall:"
  end
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
  if AGENT_CONFIG["triples"].key?(TARGET_TRIPLE)
    true
  else
    abort_installation(
      "AppSignal currently does not support your system architecture (#{TARGET_TRIPLE})." \
        "Please let us know at support@appsignal.com, we aim to support everything our customers run."
    )
  end
end

def download_archive(type)
  report["build"]["source"] = "remote"

  unless ARCH_CONFIG.key?(type)
    abort_installation(
      "AppSignal currently does not support your system. " \
        "Expected config for architecture '#{arch}' and package type '#{type}', but none found. " \
        "For a full list of supported systems visit: " \
        "https://docs.appsignal.com/support/operating-systems.html"
    )
    return
  end

  version = AGENT_CONFIG["version"]
  filename = ARCH_CONFIG[type]["filename"]
  download_errors = []

  AGENT_CONFIG["mirrors"].each do |mirror|
    download_url = [mirror, version, filename].join("/")
    report["download"]["download_url"] = download_url

    begin
      args = [
        download_url,
        :ssl_ca_cert => CA_CERT_PATH,
        :proxy => http_proxy
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

      File.open(ext_path(entry.full_name), "wb") do |f|
        f.write(entry.read)
      end
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
  proxy = try_http_proxy_value(Gem.configuration[:http_proxy])
  return proxy if proxy

  proxy = try_http_proxy_value(ENV["http_proxy"])
  return proxy if proxy

  proxy = try_http_proxy_value(ENV["HTTP_PROXY"])
  return proxy if proxy
end

def try_http_proxy_value(value)
  value if value.respond_to?(:empty?) && !value.strip.empty?
end

# Fail the installation on purpose in a specific test environment.
def fail_install_on_purpose_in_test!
  return unless ENV["_TEST_APPSIGNAL_EXTENSION_FAILURE"]

  raise "AppSignal internal test failure"
end
