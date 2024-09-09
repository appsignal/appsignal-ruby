module ApiRequestHelper
  class RequestCounter
    attr_reader :count

    def initialize
      @count = 0
    end

    def increase
      @count += 1
    end
  end

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

  def stub_cron_check_in_request(events:, response: { :status => 200 })
    stub_check_in_requests(
      :requests => [events],
      :event_shape => {
        "identifier" => nil,
        "digest" => kind_of(String),
        "kind" => nil,
        "timestamp" => kind_of(Integer),
        "check_in_type" => "cron"
      },
      :response => response
    )
  end

  def stub_heartbeat_check_in_request(events:, response: { :status => 200 })
    stub_check_in_requests(
      :requests => [events],
      :event_shape => {
        "identifier" => nil,
        "timestamp" => kind_of(Integer),
        "check_in_type" => "heartbeat"
      },
      :response => response
    )
  end

  def stub_check_in_requests(requests:, event_shape: {}, response: { :status => 200 })
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

    counter = RequestCounter.new

    request_stub =
      stub_request(
        :post,
        "#{config[:logging_endpoint]}/check_ins/json"
      ).with(options) do |request|
        events = requests.shift
        expect(events).to_not(be_nil, "More requests were made than expected")
        counter.increase
        # Parse each line as JSON per the NDJSON format
        payloads = request.body.split("\n").map { |line| JSON.parse(line) }
        formatted_events =
          events.map do |event|
            a_hash_including(**event_shape.merge(event))
          end

        expect(payloads).to include(*formatted_events)
        expect(payloads.length).to eq(formatted_events.length)
      end

    if response.is_a?(Exception)
      request_stub.to_raise(response)
    else
      request_stub.to_return(response)
    end

    counter
  end
end
