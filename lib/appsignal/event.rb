class Appsignal::Event < ActiveSupport::Notifications:: Event

  def set_payload(payload)
    @payload = payload
  end

  def to_hash
    {
      :name           => @name
      :payload        => @payload
      :time           => @start
      :transaction_id => @transaction_id
      :end            => @end
      :duration       => @duration
    }
  end
end
