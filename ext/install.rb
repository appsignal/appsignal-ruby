require 'net/http'

AGENT_VERSION   = '9234dc32'
HOST            = 'd135dj0rjqvssy.cloudfront.net'
SUPPORTED_ARCHS = %w(x86_64-linux i686-linux x86_64-darwin)

arch = "#{Gem::Platform.local.cpu}-#{Gem::Platform.local.os}"

if SUPPORTED_ARCHS.include?(arch)
  base_url   = "https://#{HOST}/#{AGENT_VERSION}/appsignal-agent-#{arch}"
  agent_url  = "#{base_url}.tar.gz"
  sha256_url = "#{base_url}.sha256"

  puts agent_url
  puts sha256_url
else
  puts "AppSignal currently does not support your system architecture (#{arch})."
  puts "Please let us know at support@appsignal.com, we aim to support everything our customers run."
end
