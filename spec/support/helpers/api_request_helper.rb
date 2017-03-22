module ApiRequestHelper
  def stub_api_request(config, path, body = nil)
    options = {
      :query => {
        :api_key => config[:push_api_key],
        :name => config[:name],
        :environment => config.env,
        :hostname => config[:hostname],
        :gem_version => Appsignal::VERSION
      },
      :headers => {
        "Content-Type" => "application/json; charset=UTF-8"
      }
    }
    body = Appsignal::Utils::JSON.generate(body) if body.is_a? Hash
    options[:body] = body if body
    stub_request(:post, "#{config[:endpoint]}/1/#{path}").with(options)
  end
end
