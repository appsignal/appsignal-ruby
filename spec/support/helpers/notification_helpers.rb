module NotificationHelpers
  def notification_event(args={})
    args = {
      :name => 'process_action.action_controller',
      :start => fixed_time,
      :ending => fixed_time + 0.1,
      :tid => '1',
      :payload => create_payload
    }.merge(args)
    ActiveSupport::Notifications::Event.new(
      args[:name], args[:start], args[:ending], args[:tid], args[:payload]
    )
  end

  def create_payload(args={})
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

  def create_background_payload(args={})
    {
      :class => 'BackgroundJob',
      :method => 'perform',
      :priority => 1,
      :attempts => 0,
      :queue => 'default',
      :queue_start => fixed_time - 10,
    }.merge(args)
  end
end
