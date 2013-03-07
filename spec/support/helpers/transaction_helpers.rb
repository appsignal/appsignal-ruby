module TransactionHelpers

  def transaction_with_exception
    appsignal_transaction.tap do |o|
      begin
        raise ArgumentError, 'oh no'
      rescue ArgumentError => exception
        env = {}
        o.add_exception(
          Appsignal::ExceptionNotification.new(env, exception)
        )
      end
    end
  end

  def regular_transaction
    appsignal_transaction(:process_action_event => notification_event)
  end

  def slow_transaction(args={})
    appsignal_transaction(
      {
        :process_action_event => notification_event(
          :start => Time.parse('01-01-2001 10:01:00'),
          :ending => (
            Time.parse('01-01-2001 10:01:00') +
            Appsignal.config[:slow_request_threshold] / 1000.0
          )
        )
      }.merge(args)
    )
  end

  def appsignal_transaction(args = {})
    process_action_event = args.delete(:process_action_event)
    events = args.delete(:events) || [
      notification_event(:name => 'query.mongoid')
    ]
    exception = args.delete(:exception)
    Appsignal::Transaction.create(
      '1',
      {
        'HTTP_USER_AGENT' => 'IE6',
        'SERVER_NAME' => 'localhost',
        'action_dispatch.routes' => 'not_available'
      }.merge(args)
    ).tap do |o|
      o.set_process_action_event(process_action_event)
      o.add_exception(exception)
      events.each { |event| o.add_event(event) }
    end
  end

end
