module TransactionHelpers

  def fixed_time
    @fixed_time ||= Time.at(978364860.0)
  end

  def transaction_with_exception
    appsignal_transaction.tap do |o|
      o.set_tags('user_id' => 123)
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
          :start => fixed_time,
          :ending => fixed_time + Appsignal.config[:slow_request_threshold] / 999.99
        )
      }.merge(args)
    )
  end

  def slower_transaction(args={})
    appsignal_transaction(
      {
        :process_action_event => notification_event(
          :start => fixed_time,
          :ending => fixed_time + Appsignal.config[:slow_request_threshold] / 499.99
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
