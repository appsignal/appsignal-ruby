require File.expand_path("../../lib/appsignal/version.rb", __FILE__)
require File.expand_path("../base.rb", __FILE__)

def install
  logger.info "Installing appsignal agent #{Appsignal::VERSION} for Ruby #{RUBY_VERSION} on #{RUBY_PLATFORM}"
  write_agent_architecture
  return unless check_architecture
  arch_config = AGENT_CONFIG["triples"][ARCH]

  unless File.exist?(ext_path("appsignal-agent")) &&
      File.exist?(ext_path("libappsignal.a")) &&
      File.exist?(ext_path("appsignal.h"))
    archive = download_archive(arch_config, "static")
    return unless archive
    return unless verify_archive(archive, arch_config, "static")
    unarchive(archive)
  end

  logger.info "Creating makefile"
  require "mkmf"
  if !have_library("appsignal", "appsignal_start", "appsignal.h")
    installation_failed "Aborting installation, libappsignal.a or appsignal.h not found"
  elsif !find_executable("appsignal-agent", EXT_PATH)
    installation_failed "Aborting installation, appsignal-agent not found"
  else
    with_static_link = [
      Appsignal::System::LINUX_TARGET,
      Appsignal::System::MUSL_TARGET
    ].include?(PLATFORM)
    if with_static_link
      # Statically link libgcc and libgcc_s libraries.
      # Dependencies of the libappsignal extension library.
      # If the gem is installed on a host with build tools installed, but is
      # run on one that isn't the missing libraries will cause the extension
      # to fail on start.
      $LDFLAGS += " -static-libgcc" # rubocop:disable Style/GlobalVars
    end
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
