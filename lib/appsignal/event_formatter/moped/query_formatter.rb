module Appsignal
  class EventFormatter
    module Moped
      class QueryFormatter < Appsignal::EventFormatter
        register 'query.moped'

        def format(payload)
          if payload[:ops] && payload[:ops].length > 0
            op = payload[:ops].first
            case op.class.to_s
            when 'Moped::Protocol::Command'
              return ['Command', {
                :database => op.full_collection_name,
                :selector => sanitize(op.selector)
              }.inspect]
            when 'Moped::Protocol::Query'
              return ['Query', {
                :database => op.full_collection_name,
                :selector => sanitize(op.selector),
                :flags    => op.flags,
                :limit    => op.limit,
                :skip     => op.skip,
                :fields   => op.fields
              }.inspect]
            when 'Moped::Protocol::Delete'
              return ['Delete', {
                :database => op.full_collection_name,
                :selector => sanitize(op.selector),
                :flags    => op.flags,
              }.inspect]
            when 'Moped::Protocol::Insert'
              return ['Insert', {
                :database   => op.full_collection_name,
                :documents  => sanitize(op.documents, true),
                :count      => op.documents.count,
                :flags      => op.flags,
              }.inspect]
            when 'Moped::Protocol::Update'
              return ['Update', {
                :database => op.full_collection_name,
                :selector => sanitize(op.selector),
                :update   => sanitize(op.update, true),
                :flags    => op.flags,
              }.inspect]
            when 'Moped::Protocol::KillCursors'
              return ['KillCursors', {
                :number_of_cursor_ids => op.number_of_cursor_ids
              }.inspect]
            else
              return [op.class.to_s.sub('Moped::Protocol::', ''), {
                :database => op.full_collection_name
              }.inspect]
            end
          end
        end

        protected

          def sanitize(params, only_top_level=false)
            if params.is_a?(Hash)
              {}.tap do |hsh|
                params.each do |key, val|
                  hsh[key] = only_top_level ? '?' : sanitize(val, only_top_level)
                end
              end
            elsif params.is_a?(Array)
              if only_top_level
                sanitize(params[0], only_top_level)
              elsif params.first.is_a?(String)
                ['?']
              else
                params.map do |item|
                  sanitize(item, only_top_level)
                end
              end
            else
              '?'
            end
          end
        end
    end
  end
end
