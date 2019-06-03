require "digest"
require "fileutils"
require "open-uri"
require "zlib"
require "yaml"
require "rubygems/package"
require File.expand_path("../../lib/appsignal/version.rb", __FILE__)
require File.expand_path("../../lib/appsignal/system.rb", __FILE__)

EXT_PATH     = File.expand_path("..", __FILE__).freeze
AGENT_CONFIG = YAML.load(File.read(File.join(EXT_PATH, "agent.yml"))).freeze

AGENT_PLATFORM = Appsignal::System.agent_platform
ARCH = "#{RbConfig::CONFIG["host_cpu"]}-#{AGENT_PLATFORM}".freeze
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
          "checksum" => "unverified"
        },
        "build" => {
          "time" => Time.now.utc,
          "package_path" => File.dirname(EXT_PATH),
          "architecture" => rbconfig["host_cpu"],
          "target" => AGENT_PLATFORM,
          "musl_override" => Appsignal::System.force_musl_build?,
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
    file.write YAML.dump(report)
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
  if AGENT_CONFIG["triples"].key?(ARCH)
    true
  else
    abort_installation(
      "AppSignal currently does not support your system architecture (#{ARCH})." \
        "Please let us know at support@appsignal.com, we aim to support everything our customers run."
    )
  end
end

def download_archive(arch_config, type)
  report["build"]["source"] = "remote"
  if arch_config.key?(type)
    download_url = arch_config[type]["download_url"]
    report["download"]["download_url"] = download_url
    open(download_url, :ssl_ca_cert => CA_CERT_PATH)
  else
    abort_installation(
      "AppSignal currently does not support your system. " \
        "Expected config for architecture '#{ARCH}' and package type '#{type}', but none found. " \
        "For a full list of supported systems visit: " \
        "https://docs.appsignal.com/support/operating-systems.html"
    )
  end
end

def verify_archive(archive, arch_config, type)
  if Digest::SHA256.hexdigest(archive.read) == arch_config[type]["checksum"]
    report["download"]["checksum"] = "verified"
    true
  else
    report["download"]["checksum"] = "invalid"
    abort_installation(
      "Checksum of downloaded archive could not be verified: " \
        "Expected '#{arch_config[type]["checksum"]}', got '#{checksum}'."
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
