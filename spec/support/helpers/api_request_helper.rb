module ApiRequestHelper
  def stub_api_request(config, path, body)
    body = Appsignal::Utils::Gzip.compress(Appsignal::Utils::JSON.generate(body))
    stub_request(:post, "#{config[:endpoint]}/1/#{path}").with(
      :body => body,
        :query => {
        :api_key => config[:push_api_key],
        :name => config[:name],
        :environment => config.env,
        :hostname => config[:hostname],
        :gem_version => Appsignal::VERSION
      },
      :headers => {
        'Content-Encoding' => 'gzip',
        'Content-Type' => 'application/json; charset=UTF-8',
      }
    )
  end
end
