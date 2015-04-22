require 'mkmf'
require 'fileutils'
require 'open-uri'
require 'zlib'
require 'rubygems/package'
require File.expand_path('../../lib/appsignal/version.rb', __FILE__)

HOST            = 'd135dj0rjqvssy.cloudfront.net'
SUPPORTED_ARCHS = %w(x86_64-linux x86_64-darwin)

def ext_path(path)
  File.join(File.expand_path('..', __FILE__), path)
end

# Clean up possibly stale agent and lib
FileUtils.rm_f(ext_path('appsignal-agent'))
FileUtils.rm_f(ext_path('libappsignal.a'))

arch = "#{Gem::Platform.local.cpu}-#{Gem::Platform.local.os}"

if SUPPORTED_ARCHS.include?(arch)
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

  require 'pry'
  binding.pry

  have_library 'appsignal', 'appsignal_start'

  create_makefile 'appsignal_extension'
else
  puts "AppSignal currently does not support your system architecture (#{arch})."
  puts "Please let us know at support@appsignal.com, we aim to support everything our customers run."
end
