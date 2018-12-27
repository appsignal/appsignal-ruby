require File.expand_path("../../lib/appsignal/version.rb", __FILE__)
require File.expand_path("../base.rb", __FILE__)

def install # rubocop:disable Metrics/CyclomaticComplexity
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

  is_linux_system = [
    Appsignal::System::LINUX_TARGET,
    Appsignal::System::MUSL_TARGET
  ].include?(PLATFORM)

  logger.info "Creating makefile"
  require "mkmf"

  link_libraries if is_linux_system

  if !have_library("appsignal", "appsignal_start", "appsignal.h")
    installation_failed "Aborting installation, libappsignal.a or appsignal.h not found"
  elsif !find_executable("appsignal-agent", EXT_PATH)
    installation_failed "Aborting installation, appsignal-agent not found"
  else
    if is_linux_system
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

# Ruby 2.6 requires us to statically link more libraries we use in our
# extension library than previous versions. Needed for normal Linux libc
# and musl builds.
def link_libraries
  if RbConfig::CONFIG["THREAD_MODEL"] == "pthread"
    logger.info "Linking extension against 'pthread' library"
    # Link gem extension against pthread library
    have_library "pthread"
    have_required_function "pthread_create"
  end

  # Links gem extension against the `dl` library. This is needed when Ruby is
  # not linked against `dl` itself, so link it on the gem extension.
  logger.info "Linking extension against 'dl' library"
  have_library "dl"
  # Check if functions are available now from the linked library
  %w[dlopen dlclose dlsym].each do |func|
    have_required_function func
  end
end

def have_required_function(func) # rubocop:disable Naming/PredicateName
  return if have_func(func)

  installation_failed "Aborting installation, missing function '#{func}'"
  # Exit with true/0/success because the AppSignal installation should never
  # break a build
  exit
end

install
