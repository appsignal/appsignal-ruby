module NotificationHelpers

  def notification_event(args={})
    time = Time.parse('01-01-2001 10:01:00')
    args = {
      :name => 'process_action.action_controller',
      :start => time,
      :ending => time + 0.100,
      :tid => '1',
      :payload => create_payload
    }.merge(args)
    ActiveSupport::Notifications::Event.new(
      args[:name], args[:start], args[:ending], args[:tid], args[:payload]
    )
  end

  def create_payload(args = {})
    {
      :path => '/blog',
      :action => 'show',
      :controller => 'BlogPostsController',
      :request_format => 'html',
      :request_method => "GET",
      :status => '200',
      :view_runtime => 500,
      :db_runtime => 500
    }.merge(args)
  end

end
