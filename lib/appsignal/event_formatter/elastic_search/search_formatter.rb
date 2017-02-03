module Appsignal
  class EventFormatter
    # @api private
    module ElasticSearch
      class SearchFormatter < Appsignal::EventFormatter
        register "search.elasticsearch"

        def format(payload)
          [
            "#{payload[:name]}: #{payload[:klass]}",
            sanitized_search(payload[:search]).inspect
          ]
        end

        def sanitized_search(search)
          return unless search.is_a?(Hash)

          {}.tap do |hsh|
            search.each do |key, val|
              hsh[key] =
                if [:index, :type].include?(key)
                  val
                else
                  Appsignal::Utils::QueryParamsSanitizer.sanitize(val)
                end
            end
          end
        end
      end
    end
  end
end
