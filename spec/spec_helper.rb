require 'rspec'
require 'rails'
require 'action_controller/railtie'

Dir[File.expand_path(File.join(File.dirname(__FILE__),'support','**','*.rb'))].each {|f| require f}

module Rails
  class Application
  end
end

module MyApp
  class Application < Rails::Application
    config.active_support.deprecation = proc { |message, stack| }
  end
end

require 'appsignal'

RSpec.configure do |config|
end

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
  appsignal_transaction(:process_action_event => create_process_action_event)
end

def slow_transaction
  appsignal_transaction(
    :process_action_event => create_process_action_event(nil, nil, Time.parse('01-01-2001 10:01:00'))
  )
end

def appsignal_transaction(args = {})
  process_action_event = args.delete(:process_action_event)
  events = args.delete(:events) || [create_process_action_event(name='query.mongoid')]
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
