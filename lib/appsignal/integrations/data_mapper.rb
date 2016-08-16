module Appsignal
  class Hooks
    module DataMapperLogListener

      def log(message)
        # Attempt to find the scheme used for this message
        scheme = self.instance_variable_get(:@uri).scheme #rescue nil

        # If scheme is SQL-like, try to sanitize it, otherwise clear the body
        if %w(sqlite sqlite3 mysql postgres).include?(scheme)
          body_content = message.query
          body_format = Appsignal::EventFormatter::SQL_BODY_FORMAT
        else
          body_content = ""
          body_format = Appsignal::EventFormatter::DEFAULT
        end

        # Record event
        Appsignal::Transaction.current.record_event(
          'query.data_mapper',
          'DataMapper Query',
          body_content,
          message.duration,
          body_format
        )
        super
      end

    end
  end
end
