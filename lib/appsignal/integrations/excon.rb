# frozen_string_literal: true

module Appsignal
  module Integrations
    # @!visibility private
    module ExconIntegration
      # The title of the event, built the way the Net::HTTP integration builds
      # its own: the request method and where the request went, without the
      # path, so paths stay out of event titles.
      #
      # Excon splits a request's data between the connection it is made on and
      # the call that makes it, so both are read to build this. Excon defaults
      # the method to GET itself, so the same default is applied here.
      def self.title_for(datum)
        method = (datum[:method] || :get).to_s.upcase
        "#{method} #{datum[:scheme]}://#{datum[:host]}"
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
        title = ExconIntegration.title_for(data.merge(params))

        Appsignal.instrument("request.excon", title) do
          if Appsignal::Transaction.current?
            # Excon retries a request, and follows a redirect, by calling this
            # method again from inside the request it is retrying or following.
            # Suppressing those means they count towards this event rather than
            # becoming events of their own, so one request stays one event.
            Appsignal::Transaction.current.suppress_http_client_events { super }
          else
            super
          end
        end
      end
    end
  end
end
