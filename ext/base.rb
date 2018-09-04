require "digest"
require "logger"
require "fileutils"
require "open-uri"
require "zlib"
require "yaml"
require "rubygems/package"
require File.expand_path("../../lib/appsignal/system.rb", __FILE__)

EXT_PATH     = File.expand_path("..", __FILE__).freeze
AGENT_CONFIG = YAML.load(File.read(File.join(EXT_PATH, "agent.yml"))).freeze

PLATFORM     = Appsignal::System.agent_platform
ARCH         = "#{RbConfig::CONFIG["host_cpu"]}-#{PLATFORM}".freeze
CA_CERT_PATH = File.join(EXT_PATH, "../resources/cacert.pem").freeze

def ext_path(path)
  File.join(EXT_PATH, path)
end

def logger
  @logger ||= Logger.new(File.join(EXT_PATH, "install.log"))
end

def installation_failed(reason)
  logger.error "Installation failed: #{reason}"
  File.open(File.join(EXT_PATH, "Makefile"), "w") do |file|
    file.write "default:\nclean:\ninstall:"
  end
end

def write_agent_architecture
  File.open(File.join(EXT_PATH, "appsignal.architecture"), "w") do |file|
    file.write ARCH
  end
end

def check_architecture
  if AGENT_CONFIG["triples"].key?(ARCH)
    true
  else
    installation_failed(
      "AppSignal currently does not support your system architecture (#{ARCH})." \
      "Please let us know at support@appsignal.com, we aim to support everything our customers run."
    )
    false
  end
end

def download_archive(arch_config, type)
  if arch_config.key?(type)
    logger.info "Downloading agent release from #{arch_config[type]["download_url"]}"
    open(arch_config[type]["download_url"], :ssl_ca_cert => CA_CERT_PATH)
  else
    installation_failed(
      "AppSignal currently does not support your system. " \
      "Expected config for architecture '#{ARCH}' and package type '#{type}', but none found. " \
      "For a full list of supported systems visit: " \
      "https://docs.appsignal.com/support/operating-systems.html"
    )
    false
  end
end

def verify_archive(archive, arch_config, type)
  if Digest::SHA256.hexdigest(archive.read) == arch_config[type]["checksum"]
    logger.info "Checksum of downloaded archive verified, extracting archive"
    true
  else
    installation_failed(
      "Aborting installation, checksum of downloaded archive could not be verified: " \
      "Expected '#{arch_config[type]["checksum"]}', got '#{checksum}'."
    )
    false
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
  FileUtils.chmod(0o755, ext_path("appsignal-agent"))
end
