module Appsignal
  class EventFormatter
    module ElasticSearch
      class SearchFormatter < Appsignal::EventFormatter
        register 'search.elasticsearch'

        def format(payload)
          [
            "#{payload[:name]}: #{payload[:klass]}",
            sanitized_search(payload[:search]).inspect
          ]
        end

        def sanitized_search(search)
          return nil unless search.is_a?(Hash)
          {}.tap do |hsh|
            search.each do |key, val|
              if [:index, :type].include?(key)
                hsh[key] = val
              else
                hsh[key] = Appsignal::Utils.sanitize(val)
              end
            end
          end
        end
      end
    end
  end
end
