module NotificationHelpers

  def create_process_action_event(name=nil, start=nil, ending=nil, tid=nil, payload=nil)
    ActiveSupport::Notifications::Event.new(
      name || 'process_action.action_controller',
      start || Time.parse("01-01-2001 10:00:00"),
      ending || Time.parse("01-01-2001 10:00:01"),
      tid || '1',
      payload || create_payload
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
