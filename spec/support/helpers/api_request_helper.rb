module ApiRequestHelper
  def stub_api_request(config, path, body = nil)
    options = {
      :query => {
        :api_key => config[:push_api_key],
        :name => config[:name],
        :environment => config.respond_to?(:env) ? config.env : config[:environment],
        :hostname => config[:hostname],
        :gem_version => Appsignal::VERSION
      },
      :headers => {
        "Content-Type" => "application/json; charset=UTF-8"
      }
    }
    body = Appsignal::Utils::JSON.generate(body) if body.is_a? Hash
    options[:body] = body if body
    endpoint = config[:endpoint] || Appsignal::Config::DEFAULT_CONFIG[:endpoint]
    stub_request(:post, "#{endpoint}/1/#{path}").with(options)
  end

  def stub_check_in_request(events:, response: { :status => 200 })
    config = Appsignal.config
    options = {
      :query => {
        :api_key => config[:push_api_key],
        :name => config[:name],
        :environment => config.respond_to?(:env) ? config.env : config[:environment],
        :hostname => config[:hostname],
        :gem_version => Appsignal::VERSION
      },
      :headers => { "Content-Type" => "application/x-ndjson; charset=UTF-8" }
    }

    request_stub =
      stub_request(
        :post,
        "#{config[:logging_endpoint]}/check_ins/json"
      ).with(options) do |request|
        # Parse each line as JSON per the NDJSON format
        payloads = request.body.split("\n").map { |line| JSON.parse(line) }
        formatted_events =
          events.map do |event|
            {
              "identifier" => nil,
              "digest" => kind_of(String),
              "kind" => "start",
              "timestamp" => kind_of(Integer),
              "check_in_type" => "cron"
            }.merge(event)
          end
        expect(payloads).to include(*formatted_events)
      end

    if response.is_a?(Exception)
      request_stub.to_raise(response)
    else
      request_stub.to_return(response)
    end
  end
end
