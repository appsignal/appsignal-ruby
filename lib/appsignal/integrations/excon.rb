# frozen_string_literal: true

module Appsignal
  module Integrations
    # @!visibility private
    module ExconIntegration
      # The method of a request. Excon defaults it to GET further down, so the
      # same default is applied here.
      def self.method_for(datum)
        datum[:method] || :get
      end

      # The title of the event, built the way the Net::HTTP integration builds
      # its own: the request method and where the request went, without the
      # path, so paths stay out of event titles.
      #
      # Excon splits a request's data between the connection it is made on and
      # the call that makes it, so both are read to build this.
      def self.title_for(datum)
        "#{method_for(datum).to_s.upcase} #{datum[:scheme]}://#{datum[:host]}"
      end

      def request(params = {})
        # Skip when an outer HTTP client integration (Faraday) already records
        # this request, so it isn't instrumented twice.
        if Appsignal::Transaction.current? &&
            Appsignal::Transaction.current.http_client_events_suppressed?
          return super
        end

        # This method is the whole of a request. Excon sends the request here,
        # waits for the response, reads it, and only then returns.
        #
        # Excon can also report a request through an instrumentor, but an
        # instrumentor cannot measure a request. Excon runs its middleware once
        # to send the request and again to read the response, and the reading
        # happens in a middleware that sits outside the one that calls the
        # instrumentor. So the wait for the remote service, which is the part of
        # a request worth measuring, falls outside everything an instrumentor is
        # told about.
        #
        # A pipelined request is the exception to this method being the whole of
        # a request. It returns before the response is read, so its event covers
        # only the sending.
        datum = data.merge(params)

        Appsignal.instrument(
          "request.excon",
          ExconIntegration.title_for(datum),
          :opentelemetry_kind => :client,
          :opentelemetry_scope => ["appsignal-ruby/excon", Appsignal::VERSION]
        ) do
          # Describes the span as an outgoing HTTP request. Together with the
          # CLIENT kind, this is what the trace timeline reads to recognize it
          # as one.
          Appsignal::Transaction.current.add_opentelemetry_attributes(
            Appsignal::OpenTelemetry::HttpClientRequest.attributes_for(
              :method => ExconIntegration.method_for(datum),
              :scheme => datum[:scheme],
              :host => datum[:host],
              :port => datum[:port],
              :path => datum[:path]
            )
          )

          response =
            if Appsignal::Transaction.current?
              # Excon retries a request, and follows a redirect, by calling this
              # method again from inside the request it is retrying or
              # following. Suppressing those means they count towards this event
              # rather than becoming events of their own, so one request stays
              # one event.
              Appsignal::Transaction.current.suppress_http_client_events { super }
            else
              super
            end

          # Describes the response on the same span as the request, which the
          # semantic conventions ask for whenever one was received.
          #
          # A pipelined request returns the request data rather than a response,
          # because its response has not been read yet, so there is no status to
          # report for it.
          Appsignal::Transaction.current.add_opentelemetry_attributes(
            Appsignal::OpenTelemetry::HttpResponse.attributes_for(
              response.respond_to?(:status) ? response.status : nil
            )
          )
          response
        end
      end
    end
  end
end
