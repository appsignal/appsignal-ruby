require 'mkmf'
require 'fileutils'
require 'open-uri'
require 'zlib'
require 'rubygems/package'
require File.expand_path('../../lib/appsignal/version.rb', __FILE__)

HOST            = 'd135dj0rjqvssy.cloudfront.net'
SUPPORTED_ARCHS = %w(x86_64-linux x86_64-darwin)
EXT_PATH        = File.expand_path('..', __FILE__)
LIB_EXTENSION   = case Gem::Platform.local.os
                  when /darwin/
                    'dylib'
                  else
                    'so'
                  end

def ext_path(path)
  File.join(EXT_PATH, path)
end

def installation_failed(reason)
  puts "Installation failed: #{reason}"
  File.open(File.join(EXT_PATH, 'Makefile'), 'w') do |file|
      file.write "default:\nclean:\ninstall:"
  end
end

arch = "#{Gem::Platform.local.cpu}-#{Gem::Platform.local.os}"

if SUPPORTED_ARCHS.include?(arch)
  begin
    if !File.exists?(ext_path('appsignal-agent')) || !File.exists?(ext_path("libappsignal.#{LIB_EXTENSION}"))
      archive_url = "https://#{HOST}/#{Appsignal::AGENT_VERSION}/appsignal-agent-#{arch}.tar.gz"
      archive     = open(archive_url)
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

    if find_library('appsignal', 'appsignal_start', EXT_PATH) &&
         find_executable('appsignal-agent', EXT_PATH) &&
         find_header('appsignal_extension.h', EXT_PATH)
      create_makefile 'appsignal_extension'
    else
      installation_failed("Extension files were not present")
    end
  rescue => ex
      installation_failed("Exception while installing: #{ex}")
  end
else
  installation_failed(
    "AppSignal currently does not support your system architecture (#{arch})." \
    "Please let us know at support@appsignal.com, we aim to support everything our customers run."
  )
end
