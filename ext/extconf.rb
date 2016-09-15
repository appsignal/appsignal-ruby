require 'digest'
require 'logger'
require 'fileutils'
require 'open-uri'
require 'zlib'
require 'rubygems/package'
require 'yaml'
require File.expand_path('../../lib/appsignal/version.rb', __FILE__)

EXT_PATH     = File.expand_path('..', __FILE__)
AGENT_CONFIG = YAML.load(File.read(File.join(EXT_PATH, 'agent.yml')))
ARCH         = "#{Gem::Platform.local.cpu}-#{Gem::Platform.local.os}"
CA_CERT_PATH = File.join(EXT_PATH, '../resources/cacert.pem')

def ext_path(path)
  File.join(EXT_PATH, path)
end

def logger
  @logger ||= Logger.new(File.join(EXT_PATH, 'install.log'))
end

def installation_failed(reason)
  logger.error "Installation failed: #{reason}"
  File.open(File.join(EXT_PATH, 'Makefile'), 'w') do |file|
      file.write "default:\nclean:\ninstall:"
  end
end

def install
  logger.info "Installing appsignal agent #{Appsignal::VERSION} for Ruby #{RUBY_VERSION} on #{RUBY_PLATFORM}"

  if RUBY_PLATFORM =~ /java/
    installation_failed(
      "We do not support jRuby at the moment, email support@appsignal.com if you want to join the beta"
    )
    return
  end

  unless AGENT_CONFIG['triples'].keys.include?(ARCH)
    installation_failed(
      "AppSignal currently does not support your system architecture (#{ARCH})." \
      "Please let us know at support@appsignal.com, we aim to support everything our customers run."
    )
    return
  end

  arch_config = AGENT_CONFIG['triples'][ARCH]

  unless File.exist?(ext_path('appsignal-agent')) &&
           File.exist?(ext_path('libappsignal.a')) &&
           File.exist?(ext_path('appsignal.h'))
    logger.info "Downloading agent release from #{arch_config['download_url']}"

    archive = open(arch_config['download_url'], :ssl_ca_cert => CA_CERT_PATH)

    if Digest::SHA256.hexdigest(archive.read) == arch_config['checksum']
      logger.info 'Checksum of downloaded archive verified, extracting archive'
    else
      installation_failed(
        "Aborting installation, checksum of downloaded archive could not be verified: " \
        "Expected '#{arch_config['checksum']}', got '#{checksum}'."
      )
      return
    end

    Gem::Package::TarReader.new(Zlib::GzipReader.open(archive)) do |tar|
      tar.each do |entry|
        if entry.file?
          File.open(ext_path(entry.full_name), 'wb') do |f|
            f.write(entry.read)
          end
        end
      end
    end
    FileUtils.chmod(0755, ext_path('appsignal-agent'))
  end

  logger.info "Creating makefile"
  require 'mkmf'
  logger.info "find_library"
  logger.info find_library('appsignal', 'appsignal_start', EXT_PATH).inspect
  logger.info "find_executable"
  logger.info find_executable('appsignal-agent', EXT_PATH).inspect
  logger.info "find_header"
  logger.info find_header('appsignal.h', EXT_PATH).inspect
  if !find_library('appsignal', 'appsignal_start', EXT_PATH)
    installation_failed 'Aborting installation, libappsignal not found'
  elsif !find_executable('appsignal-agent', EXT_PATH)
    installation_failed 'Aborting installation, appsignal-agent not found'
  elsif !find_header('appsignal.h', EXT_PATH)
    installation_failed 'Aborting installation, appsignal.h not found'
  else
    create_makefile 'appsignal_extension'
    logger.info 'Successfully created Makefile for appsignal extension'
  end
rescue => ex
  installation_failed "Exception while installing: #{ex}"
  ex.backtrace.each do |line|
    logger.error line
  end
end

install
