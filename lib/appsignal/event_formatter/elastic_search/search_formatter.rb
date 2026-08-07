# frozen_string_literal: true

module Appsignal
  class EventFormatter
    # @!visibility private
    module ElasticSearch
      class SearchFormatter < Appsignal::EventFormatter
        # A search is an outgoing call to an Elasticsearch cluster.
        def opentelemetry_kind
          :client
        end

        def opentelemetry_attributes(payload)
          {
            "db.system.name" => "elasticsearch",
            # This notification is only emitted for a search, so that is the
            # operation every one of these spans describes.
            "db.operation.name" => "search",
            "db.collection.name" => search_index(payload)
          }.compact
        end

        def format(payload)
          [
            "#{payload[:name]}: #{payload[:klass]}",
            sanitized_search(payload[:search]).inspect
          ]
        end

        # The index a search ran against, which the notification carries in the
        # search it describes. A search that names more than one index, or none
        # at all, is left without this attribute rather than described with a
        # value that is not an index name.
        def search_index(payload)
          search = payload[:search]
          return unless search.respond_to?(:[])

          index = search[:index]
          index if index.is_a?(String)
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

Appsignal::EventFormatter.register(
  "search.elasticsearch",
  Appsignal::EventFormatter::ElasticSearch::SearchFormatter
)
