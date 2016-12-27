module Appsignal
  class EventFormatter
    module Moped
      class QueryFormatter < Appsignal::EventFormatter
        register "query.moped"

        def format(payload)
          if payload[:ops] && payload[:ops].length > 0
            op = payload[:ops].first
            case op.class.to_s
            when "Moped::Protocol::Command"
              return ["Command", {
                :database => op.full_collection_name,
                :selector => sanitize(op.selector, true, :mongodb)
              }.inspect]
            when "Moped::Protocol::Query"
              return ["Query", {
                :database => op.full_collection_name,
                :selector => sanitize(op.selector, false, :mongodb),
                :flags    => op.flags,
                :limit    => op.limit,
                :skip     => op.skip,
                :fields   => op.fields
              }.inspect]
            when "Moped::Protocol::Delete"
              return ["Delete", {
                :database => op.full_collection_name,
                :selector => sanitize(op.selector, false, :mongodb),
                :flags    => op.flags,
              }.inspect]
            when "Moped::Protocol::Insert"
              return ["Insert", {
                :database   => op.full_collection_name,
                :documents  => sanitize(op.documents, true, :mongodb),
                :count      => op.documents.count,
                :flags      => op.flags,
              }.inspect]
            when "Moped::Protocol::Update"
              return ["Update", {
                :database => op.full_collection_name,
                :selector => sanitize(op.selector, false, :mongodb),
                :update   => sanitize(op.update, true, :mongodb),
                :flags    => op.flags,
              }.inspect]
            when "Moped::Protocol::KillCursors"
              return ["KillCursors", {
                :number_of_cursor_ids => op.number_of_cursor_ids
              }.inspect]
            else
              return [op.class.to_s.sub("Moped::Protocol::", ""), {
                :database => op.full_collection_name
              }.inspect]
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
