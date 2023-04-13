# frozen_string_literal: true

require File.expand_path("base.rb", __dir__)

def local_build?
  File.exist?(ext_path("appsignal-agent")) &&
    File.exist?(ext_path("libappsignal.a")) &&
    File.exist?(ext_path("appsignal.h"))
end

def install
  fail_install_on_purpose_in_test!

  library_type = "static"
  report["language"]["implementation"] = "ruby"
  report["build"]["library_type"] = library_type
  return unless check_architecture

  if local_build?
    report["build"]["source"] = "local"
  else
    archive = download_archive(library_type)
    return unless archive
    return unless verify_archive(archive, library_type)

    unarchive(archive)
  end

  is_linux_system = [
    Appsignal::System::LINUX_TARGET,
    Appsignal::System::MUSL_TARGET
  ].include?(AGENT_PLATFORM)

  require "mkmf"
  link_libraries if is_linux_system

  if !have_library("appsignal", "appsignal_start", "appsignal.h")
    abort_installation("Library libappsignal.a or appsignal.h not found")
  elsif !find_executable("appsignal-agent", EXT_PATH)
    abort_installation("File appsignal-agent not found")
  else
    if is_linux_system
      # Statically link libgcc and libgcc_s libraries.
      # Dependencies of the libappsignal extension library.
      # If the gem is installed on a host with build tools installed, but is
      # run on one that isn't the missing libraries will cause the extension
      # to fail on start.
      $LDFLAGS += " -static-libgcc" # rubocop:disable Style/GlobalVars
      report["build"]["flags"]["LDFLAGS"] = $LDFLAGS # rubocop:disable Style/GlobalVars
    end
    create_makefile "appsignal_extension"
    successful_installation
  end
rescue => error
  fail_installation_with_error(error)
ensure
  create_dummy_makefile unless installation_succeeded?
  write_report
end

# Ruby 2.6 requires us to statically link more libraries we use in our
# extension library than previous versions. Needed for normal Linux libc
# and musl builds.
def link_libraries
  if RbConfig::CONFIG["THREAD_MODEL"] == "pthread"
    # Link gem extension against pthread library
    have_library "pthread"
    have_required_function "pthread", "pthread_create"
  end

  # Links gem extension against the `dl` library. This is needed when Ruby is
  # not linked against `dl` itself, so link it on the gem extension.
  have_library "dl"
  # Check if functions are available now from the linked library
  %w[dlopen dlclose dlsym].each do |func|
    have_required_function "dl", func
  end
end

def have_required_function(library, func) # rubocop:disable Naming/PredicateName
  if have_func(func)
    report["build"]["dependencies"][library] = "linked"
    return
  end

  report["build"]["dependencies"][library] = "not linked"
  abort_installation("Missing function '#{func}'")
  # Exit with true/0/success because the AppSignal installation should never
  # break a build
  exit
end

install
