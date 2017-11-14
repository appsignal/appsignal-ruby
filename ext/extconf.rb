require "digest"
require "logger"
require "fileutils"
require "open-uri"
require "zlib"
require "rubygems/package"
require "yaml"
require File.expand_path("../../lib/appsignal/version.rb", __FILE__)
require File.expand_path("../../lib/appsignal/system.rb", __FILE__)

EXT_PATH     = File.expand_path("..", __FILE__).freeze
AGENT_CONFIG = YAML.load(File.read(File.join(EXT_PATH, "agent.yml"))).freeze

PLATFORM     = Appsignal::System.agent_platform
ARCH         = "#{Gem::Platform.local.cpu}-#{PLATFORM}".freeze
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

def install
  logger.info "Installing appsignal agent #{Appsignal::VERSION} for Ruby #{RUBY_VERSION} on #{RUBY_PLATFORM}"
  write_agent_architecture

  if RUBY_PLATFORM =~ /java/
    installation_failed(
      "We do not support jRuby at the moment, email support@appsignal.com if you want to join the beta"
    )
    return
  end

  unless AGENT_CONFIG["triples"].keys.include?(ARCH)
    installation_failed(
      "AppSignal currently does not support your system architecture (#{ARCH})." \
      "Please let us know at support@appsignal.com, we aim to support everything our customers run."
    )
    return
  end

  arch_config = AGENT_CONFIG["triples"][ARCH]

  unless File.exist?(ext_path("appsignal-agent")) &&
      File.exist?(ext_path("libappsignal.a")) &&
      File.exist?(ext_path("appsignal.h"))
    logger.info "Downloading agent release from #{arch_config["download_url"]}"

    archive = open(arch_config["download_url"], :ssl_ca_cert => CA_CERT_PATH)

    if Digest::SHA256.hexdigest(archive.read) == arch_config["checksum"]
      logger.info "Checksum of downloaded archive verified, extracting archive"
    else
      installation_failed(
        "Aborting installation, checksum of downloaded archive could not be verified: " \
        "Expected '#{arch_config["checksum"]}', got '#{checksum}'."
      )
      return
    end

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

  logger.info "Creating makefile"
  require "mkmf"
  if !have_library("appsignal", "appsignal_start", "appsignal.h")
    installation_failed "Aborting installation, libappsignal.a or appsignal.h not found"
  elsif !find_executable("appsignal-agent", EXT_PATH)
    installation_failed "Aborting installation, appsignal-agent not found"
  else
    create_makefile "appsignal_extension"
    logger.info "Successfully created Makefile for appsignal extension"
  end
rescue => ex
  installation_failed "Exception while installing: #{ex}"
  ex.backtrace.each do |line|
    logger.error line
  end
end

install
