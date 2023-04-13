# frozen_string_literal: true

module Appsignal
  class EventFormatter
    # @api private
    module MongoRubyDriver
      class QueryFormatter
        ALLOWED = {
          "find" => {
            "find" => :allow,
            "filter" => :sanitize_document
          },
          "count" => {
            "count" => :allow,
            "query" => :sanitize_document
          },
          "distinct" => {
            "distinct" => :allow,
            "key" => :allow,
            "query" => :sanitize_document
          },
          "insert" => {
            "insert" => :allow,
            "documents" => :sanitize_document,
            "ordered" => :allow
          },
          "update" => {
            "update" => :allow,
            "updates" => :sanitize_document,
            "ordered" => :allow
          },
          "findandmodify" => {
            "findandmodify" => :allow,
            "query" => :sanitize_document,
            "update" => :sanitize_document,
            "new" => :allow
          },
          "delete" => {
            "delete" => :allow,
            "deletes" => :sanitize_document,
            "ordered" => :allow
          },
          "bulk" => {
            "q" => :sanitize_document,
            "u" => :sanitize_document,
            "limit" => :allow,
            "multi" => :allow,
            "upsert" => :allow
          }
        }.freeze

        # Format command based on given strategy
        def self.format(strategy, command)
          # Stop processing if command is not a hash
          return {} unless command.is_a?(Hash)

          # Get the strategy and stop if it's not present
          strategies = ALLOWED[strategy.to_s]
          return {} unless strategies

          {}.tap do |hsh|
            command.each do |key, val|
              hsh[key] = apply_strategy(strategies[key], val)
            end
          end
        end

        # Applies strategy on hash values based on keys
        def self.apply_strategy(strategy, val)
          case strategy
          when :allow then val
          when :sanitize_document
            Appsignal::Utils::QueryParamsSanitizer.sanitize(val, false, :mongodb)
          else "?"
          end
        end
      end
    end
  end
end
