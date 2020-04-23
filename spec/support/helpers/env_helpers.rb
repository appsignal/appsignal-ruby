module EnvHelpers
  def http_request_env_with_data(args = {})
    path = args.delete(:path) || "/blog"
    Rack::MockRequest.env_for(
      path,
      :params => args[:params] || {
        "controller" => "blog_posts",
        "action" => "show",
        "id" => "1"
      }
    ).merge(
      :controller => "BlogPostsController",
      :action => "show",
      :request_format => "html",
      :request_method => "GET",
      :status => "200",
      :view_runtime => 500,
      :db_runtime => 500,
      :metadata => { :key => "value" }
    ).merge(args)
  end

  def background_env_with_data(args = {})
    {
      :class => "BackgroundJob",
      :method => "perform",
      :priority => 1,
      :attempts => 0,
      :queue => "default",
      :queue_start => fixed_time
    }.merge(args)
  end
end
