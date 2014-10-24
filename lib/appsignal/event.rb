class Appsignal::Event < ActiveSupport::Notifications::Event
  def sanitize!
    @payload = Appsignal::ParamsSanitizer.sanitize(@payload)
  end

  def truncate!
    @payload = {}
  end

  def self.event_for_instrumentation(*args)
    case args[0]
    when 'query.moped'
      Appsignal::Event::MopedEvent.new(*args)
    else
      new(*args)
    end
  end
end

require 'appsignal/event/moped_event'
