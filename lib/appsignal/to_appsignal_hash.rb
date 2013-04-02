module Appsignal
  module ToAppsignalHash

    def to_appsignal_hash
      {
        :name => name,
        :duration => duration,
        :time => time.to_f,
        :end => self.end.to_f,
        :payload => payload
      }
    end

  end
end


module ActiveSupport
  module Notifications
    class Event
      include Appsignal::ToAppsignalHash
    end
  end
end
