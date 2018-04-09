module Appsignal
  class EventFormatter
    # @api private
    module Moped
      class QueryFormatter
        def format(payload)
          if payload[:ops] && !payload[:ops].empty?
            op = payload[:ops].first
            case op.class.to_s
            when "Moped::Protocol::Command"
              [
                "Command", {
                  :database => op.full_collection_name,
                  :selector => sanitize(op.selector, true, :mongodb)
                }.inspect
              ]
            when "Moped::Protocol::Query"
              [
                "Query", {
                  :database => op.full_collection_name,
                  :selector => sanitize(op.selector, false, :mongodb),
                  :flags    => op.flags,
                  :limit    => op.limit,
                  :skip     => op.skip,
                  :fields   => op.fields
                }.inspect
              ]
            when "Moped::Protocol::Delete"
              [
                "Delete", {
                  :database => op.full_collection_name,
                  :selector => sanitize(op.selector, false, :mongodb),
                  :flags    => op.flags
                }.inspect
              ]
            when "Moped::Protocol::Insert"
              [
                "Insert", {
                  :database   => op.full_collection_name,
                  :documents  => sanitize(op.documents, true, :mongodb),
                  :count      => op.documents.count,
                  :flags      => op.flags
                }.inspect
              ]
            when "Moped::Protocol::Update"
              [
                "Update",
                {
                  :database => op.full_collection_name,
                  :selector => sanitize(op.selector, false, :mongodb),
                  :update   => sanitize(op.update, true, :mongodb),
                  :flags    => op.flags
                }.inspect
              ]
            when "Moped::Protocol::KillCursors"
              [
                "KillCursors",
                { :number_of_cursor_ids => op.number_of_cursor_ids }.inspect
              ]
            else
              [
                op.class.to_s.sub("Moped::Protocol::", ""),
                { :database => op.full_collection_name }.inspect
              ]
            end
          end
        end

        private

        def sanitize(params, only_top_level, key_sanitizer)
          Appsignal::Utils::QueryParamsSanitizer.sanitize \
            params, only_top_level, key_sanitizer
        end
      end
    end
  end
end

Appsignal::EventFormatter.register(
  "query.moped",
  Appsignal::EventFormatter::Moped::QueryFormatter
)
