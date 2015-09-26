lib_extension = case Gem::Platform.local.os
                when /darwin/
                  'dylib'
                else
                  'so'
                end
lib_path = File.join(File.dirname(__FILE__), "../../ext/libappsignal.#{lib_extension}")

begin
  require 'fiddle'
  Fiddle.dlopen(lib_path)
rescue LoadError
  # This is Ruby 2.1 or older
  require 'dl'
  DL.dlopen(lib_path)
end

require 'appsignal_extension'
