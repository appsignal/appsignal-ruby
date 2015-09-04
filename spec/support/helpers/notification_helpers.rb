module NotificationHelpers
  def notification_event(args={})
    args = {
      :name => 'process_action.action_controller',
      :start => fixed_time,
      :ending => fixed_time + 0.1,
      :tid => '1',
      :payload => http_request_env_with_data
    }.merge(args)
    ActiveSupport::Notifications::Event.new(
      args[:name], args[:start], args[:ending], args[:tid], args[:payload]
    )
  end
end
