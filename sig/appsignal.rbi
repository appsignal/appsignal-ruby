# typed: strong
# AppSignal for Ruby gem's main module.
# 
# Provides method to control the AppSignal instrumentation and the system
# agent. Also provides direct access to instrumentation helpers (from
# {Appsignal::Helpers::Instrumentation}) and metrics helpers (from
# {Appsignal::Helpers::Metrics}) for ease of use.
module Appsignal
  extend Appsignal::Helpers::Metrics
  extend Appsignal::Helpers::Instrumentation
  VERSION = T.let("4.5.17", T.untyped)

  class << self
    # The loaded AppSignal configuration.
    # Returns the current AppSignal configuration.
    # 
    # Can return `nil` if no configuration has been set or automatically loaded
    # by an automatic integration or by calling {.start}.
    # 
    # ```ruby
    # Appsignal.config
    # ```
    # 
    # _@see_ `configure`
    # 
    # _@see_ `Config`
    sig { returns(T.nilable(Config)) }
    attr_reader :config

    # Returns the error that was encountered while loading the `appsignal.rb`
    # config file.
    # 
    # It does not include any error that occurred while loading the
    # `appsignal.yml` file.
    # 
    # If the value is `nil`, no error was encountered or AppSignal wasn't
    # started yet.
    sig { returns(T.nilable(Exception)) }
    attr_reader :config_error
  end

  # Start the AppSignal integration.
  # 
  # Starts AppSignal with the given configuration. If no configuration is set
  # yet it will try to automatically load the configuration using the
  # environment loaded from environment variables and the currently working
  # directory.
  # 
  # This is not required for the automatic integrations AppSignal offers, but
  # this is required for all non-automatic integrations and pure Ruby
  # applications. For more information, see our [integrations
  # list](https://docs.appsignal.com/ruby/integrations/) and our [Integrating
  # AppSignal](https://docs.appsignal.com/ruby/instrumentation/integrating-appsignal.html)
  # guide.
  # 
  # ```ruby
  # Appsignal.start
  # ```
  # 
  # with custom loaded configuration
  # ```ruby
  # Appsignal.configure(:production) do |config|
  #   config.ignore_actions = ["My action"]
  # end
  # Appsignal.start
  # ```
  sig { void }
  def self.start; end

  # Stop AppSignal's agent.
  # 
  # Stops the AppSignal agent. Call this before the end of your program to
  # make sure the agent is stopped as well.
  # 
  # _@param_ `called_by` — Name of the thing that requested the agent to be stopped. Will be used in the AppSignal log file.
  # 
  # ```ruby
  # Appsignal.start
  # # Run your application
  # Appsignal.stop
  # ```
  sig { params(called_by: T.nilable(String)).void }
  def self.stop(called_by = nil); end

  # Configure the AppSignal Ruby gem using a DSL.
  # 
  # Pass a block to the configure method to configure the Ruby gem.
  # 
  # Each config option defined in our docs can be fetched, set and modified
  # via a helper method in the given block.
  # 
  # After AppSignal has started using {start}, the configuration can not be
  # modified. Any calls to this helper will be ignored.
  # 
  # This helper should not be used to configure multiple environments, like
  # done in the YAML file. Configure the environment you want active when the
  # application starts.
  # 
  # _@param_ `env_param` — The environment to load.
  # 
  # _@param_ `root_path` — The path to look the `config/appsignal.yml` config file in. Defaults to the current working directory.
  # 
  # Configure AppSignal for the application
  # ```ruby
  # Appsignal.configure do |config|
  #   config.path = "/the/app/path"
  #   config.active = ENV["APP_ACTIVE"] == "true"
  #   config.push_api_key = File.read("appsignal_key.txt").chomp
  #   config.ignore_actions = ENDPOINTS.select { |e| e.public? }.map(&:name)
  #   config.request_headers << "MY_CUSTOM_HEADER"
  # end
  # ```
  # 
  # Configure AppSignal for the application and select the environment
  # ```ruby
  # Appsignal.configure(:production) do |config|
  #   config.active = true
  # end
  # ```
  # 
  # Automatically detects the app environment
  # ```ruby
  # # Tries to determine the app environment automatically from the
  # # environment and the libraries it integrates with.
  # ENV["RACK_ENV"] = "production"
  # 
  # Appsignal.configure do |config|
  #   config.env # => "production"
  # end
  # ```
  # 
  # Calling configure multiple times for different environments resets the configuration
  # ```ruby
  # Appsignal.configure(:development) do |config|
  #   config.ignore_actions = ["My action"]
  # end
  # 
  # Appsignal.configure(:production) do |config|
  #   config.ignore_actions # => []
  # end
  # ```
  # 
  # Load config without a block
  # ```ruby
  # # This will require either ENV vars being set
  # # or the config/appsignal.yml being present
  # Appsignal.configure
  # # Or for the environment given as an argument
  # Appsignal.configure(:production)
  # ```
  # 
  # _@see_ `config`
  # 
  # _@see_ `Config`
  # 
  # _@see_ `https://docs.appsignal.com/ruby/configuration.html` — Configuration guide
  # 
  # _@see_ `https://docs.appsignal.com/ruby/configuration/options.html` — Configuration options
  sig { params(env_param: T.nilable(T.any(String, Symbol)), root_path: T.nilable(String), blk: T.proc.params(config_dsl: Appsignal::Config::ConfigDSL).void).void }
  def self.configure(env_param = nil, root_path: nil, &blk); end

  sig { void }
  def self.forked; end

  # Load an AppSignal integration.
  # 
  # Load one of the supported integrations via our loader system.
  # This will set config defaults and integratie with the library if
  # AppSignal is active upon start.
  # 
  # _@param_ `integration_name` — Name of the integration to load.
  # 
  # Load Sinatra integrations
  # ```ruby
  # # First load the integration
  # Appsignal.load(:sinatra)
  # # Start AppSignal
  # Appsignal.start
  # ```
  # 
  # Load Sinatra integrations and define custom config
  # ```ruby
  # # First load the integration
  # Appsignal.load(:sinatra)
  # 
  # # Customize config
  # Appsignal.configure do |config|
  #   config.ignore_actions = ["GET /ping"]
  # end
  # 
  # # Start AppSignal
  # Appsignal.start
  # ```
  sig { params(integration_name: T.any(String, Symbol)).void }
  def self.load(integration_name); end

  # Returns if the C-extension was loaded properly.
  # 
  # _@see_ `Extension`
  sig { returns(T::Boolean) }
  def self.extension_loaded?; end

  # Returns if {.start} has been called before with a valid config to start
  # AppSignal.
  # 
  # _@see_ `Extension`
  sig { returns(T::Boolean) }
  def self.started?; end

  # Returns the active state of the AppSignal integration.
  # 
  # Conditions apply for AppSignal to be marked as active:
  # 
  # - There is a config set on the {.config} attribute.
  # - The set config is active {Config.active?}.
  # - The AppSignal Extension is loaded {.extension_loaded?}.
  # 
  # This logic is used within instrument helper such as {.instrument} so it's
  # not necessary to wrap {.instrument} calls with this method.
  # 
  # Do this
  # ```ruby
  # Appsignal.instrument(..) do
  #   # Do this
  # end
  # ```
  # 
  # Don't do this
  # ```ruby
  # if Appsignal.active?
  #   Appsignal.instrument(..) do
  #     # Don't do this
  #   end
  # end
  # ```
  sig { returns(T::Boolean) }
  def self.active?; end

  # Check if the AppSignal Ruby gem has started successfully.
  # 
  # If it has not (yet) started or encountered an error in the
  # `config/appsignal.rb` config file during start up that prevented it from
  # starting, it will raise a {Appsignal::NotStartedError}.
  # 
  # If there an error raised from the config file, it will include it as the
  # error cause of the raised error.
  sig { void }
  def self.check_if_started!; end

  # Report a gauge metric.
  # 
  # _@param_ `name` — The name of the metric.
  # 
  # _@param_ `value` — The value of the metric.
  # 
  # _@param_ `tags` — The tags for the metric. The Hash keys can be either a String or a Symbol. The tag values can be a String, Symbol, Integer, Float, TrueClass or FalseClass.
  # 
  # _@see_ `https://docs.appsignal.com/metrics/custom.html` — Metrics documentation
  sig { params(name: T.any(String, Symbol), value: T.any(Integer, Float), tags: T::Hash[String, Object]).void }
  def self.set_gauge(name, value, tags = {}); end

  # Report a counter metric.
  # 
  # _@param_ `name` — The name of the metric.
  # 
  # _@param_ `value` — The value of the metric.
  # 
  # _@param_ `tags` — The tags for the metric. The Hash keys can be either a String or a Symbol. The tag values can be a String, Symbol, Integer, Float, TrueClass or FalseClass.
  # 
  # _@see_ `https://docs.appsignal.com/metrics/custom.html` — Metrics documentation
  sig { params(name: T.any(String, Symbol), value: T.any(Integer, Float), tags: T::Hash[String, Object]).void }
  def self.increment_counter(name, value = 1.0, tags = {}); end

  # Report a distribution metric.
  # 
  # _@param_ `name` — The name of the metric.
  # 
  # _@param_ `value` — The value of the metric.
  # 
  # _@param_ `tags` — The tags for the metric. The Hash keys can be either a String or a Symbol. The tag values can be a String, Symbol, Integer, Float, TrueClass or FalseClass.
  # 
  # _@see_ `https://docs.appsignal.com/metrics/custom.html` — Metrics documentation
  sig { params(name: T.any(String, Symbol), value: T.any(Integer, Float), tags: T::Hash[String, Object]).void }
  def self.add_distribution_value(name, value, tags = {}); end

  # Monitor a block of code with AppSignal.
  # 
  # This is a helper to create an AppSignal transaction, track any errors
  # that may occur and complete the transaction.
  # 
  # This helper is recommended to be used in Ruby scripts and parts of an
  # app not already instrumented by AppSignal's automatic instrumentations.
  # 
  # Use this helper in combination with our {.instrument} helper to track
  # instrumentation events.
  # 
  # If AppSignal is not active ({Appsignal.active?}) it will still execute
  # the block, but not create a transaction for it.
  # 
  # _@param_ `namespace` — The namespace to set on the new transaction. Defaults to the 'web' namespace. This will not update the active transaction's namespace if {.monitor} is called when another transaction is already active.
  # 
  # _@param_ `action` — The action name for the transaction. The action name is required to be set for the transaction to be reported. The argument can be set to `nil` or `:set_later` if the action is set within the block with {#set_action}. This will not update the active transaction's action if {.monitor} is called when another transaction is already active.
  # 
  # _@return_ — The value of the given block is returned.
  # Returns `nil` if there already is a transaction active and no block
  # was given.
  # 
  # Instrument a block of code
  # ```ruby
  # Appsignal.monitor(
  #   :namespace => "my_namespace",
  #   :action => "MyClass#my_method"
  # ) do
  #   # Some code
  # end
  # ```
  # 
  # Instrument a block of code using the default namespace
  # ```ruby
  # Appsignal.monitor(
  #   :action => "MyClass#my_method"
  # ) do
  #   # Some code
  # end
  # ```
  # 
  # Instrument a block of code with an instrumentation event
  # ```ruby
  # Appsignal.monitor(
  #   :namespace => "my_namespace",
  #   :action => "MyClass#my_method"
  # ) do
  #   Appsignal.instrument("some_event.some_group") do
  #     # Some code
  #   end
  # end
  # ```
  # 
  # Set the action name in the monitor block
  # ```ruby
  # Appsignal.monitor(
  #   :action => nil
  # ) do
  #   # Some code
  # 
  #   Appsignal.set_action("GET /resource/:id")
  # end
  # ```
  # 
  # Set the action name in the monitor block
  # ```ruby
  # Appsignal.monitor(
  #   :action => :set_later # Explicit placeholder
  # ) do
  #   # Some code
  # 
  #   Appsignal.set_action("GET /resource/:id")
  # end
  # ```
  # 
  # Set custom metadata on the transaction
  # ```ruby
  # Appsignal.monitor(
  #   :namespace => "my_namespace",
  #   :action => "MyClass#my_method"
  # ) do
  #   # Some code
  # 
  #   Appsignal.add_tags(:tag1 => "value1", :tag2 => "value2")
  #   Appsignal.add_params(:param1 => "value1", :param2 => "value2")
  # end
  # ```
  # 
  # Call monitor within monitor will do nothing
  # ```ruby
  # Appsignal.monitor(
  #   :namespace => "my_namespace",
  #   :action => "MyClass#my_method"
  # ) do
  #   # This will _not_ update the namespace and action name
  #   Appsignal.monitor(
  #     :namespace => "my_other_namespace",
  #     :action => "MyOtherClass#my_other_method"
  #   ) do
  #     # Some code
  # 
  #     # The reported namespace will be "my_namespace"
  #     # The reported action will be "MyClass#my_method"
  #   end
  # end
  # ```
  # 
  # _@see_ `https://docs.appsignal.com/ruby/instrumentation/background-jobs.html` — Monitor guide
  sig { params(action: T.any(String, Symbol, NilClass), namespace: T.nilable(T.any(String, Symbol)), blk: T.proc.returns(Object)).returns(T.nilable(Object)) }
  def self.monitor(action:, namespace: nil, &blk); end

  # Instrument a block of code and stop AppSignal.
  # 
  # Useful for cases such as one-off scripts where there is no long running
  # process active and the data needs to be sent after the process exists.
  # 
  # Acts the same way as {.monitor}. See that method for more
  # documentation.
  # 
  # _@param_ `namespace` — The namespace to set on the new transaction. Defaults to the 'web' namespace. This will not update the active transaction's namespace if {.monitor} is called when another transaction is already active.
  # 
  # _@param_ `action` — The action name for the transaction. The action name is required to be set for the transaction to be reported. The argument can be set to `nil` or `:set_later` if the action is set within the block with {#set_action}. This will not update the active transaction's action if {.monitor} is called when another transaction is already active.
  # 
  # _@return_ — The value of the given block is returned.
  # 
  # _@see_ `monitor`
  sig { params(action: T.any(String, Symbol, NilClass), namespace: T.nilable(T.any(String, Symbol)), block: T.proc.returns(Object)).returns(T.nilable(Object)) }
  def self.monitor_and_stop(action:, namespace: nil, &block); end

  # Send an error to AppSignal regardless of the context.
  # 
  # **We recommend using the {#report_error} helper instead.**
  # 
  # Records and send the exception to AppSignal.
  # 
  # This instrumentation helper does not require a transaction to be
  # active, it starts a new transaction by itself.
  # 
  # Use {.set_error} if your want to add an exception to the current
  # transaction.
  # 
  # **Note**: Does not do anything if AppSignal is not active or when the
  # "error" is not a class extended from Ruby's Exception class.
  # 
  # _@param_ `error` — The error to send to AppSignal.
  # 
  # Send an exception
  # ```ruby
  # begin
  #   raise "oh no!"
  # rescue => e
  #   Appsignal.send_error(e)
  # end
  # ```
  # 
  # Add more metadata to transaction
  # ```ruby
  # Appsignal.send_error(e) do
  #   Appsignal.set_namespace("my_namespace")
  #   Appsignal.set_action("my_action_name")
  #   Appsignal.add_params(:search_query => params[:search_query])
  #   Appsignal.add_tags(:key => "value")
  # end
  # ```
  # 
  # _@see_ `https://docs.appsignal.com/ruby/instrumentation/exception-handling.html` — Exception handling guide
  sig { params(error: Exception, block: T.proc.params(transaction: Transaction).void).void }
  def self.send_error(error, &block); end

  # Set an error on the current transaction.
  # 
  # **We recommend using the {#report_error} helper instead.**
  # 
  # **Note**: Does not do anything if AppSignal is not active, no
  # transaction is currently active or when the "error" is not a class
  # extended from Ruby's Exception class.
  # 
  # _@param_ `exception` — The error to add to the current transaction.
  # 
  # Manual instrumentation of set_error.
  # ```ruby
  # # Manually starting AppSignal here
  # # Manually starting a transaction here.
  # begin
  #   raise "oh no!"
  # rescue => e
  #   Appsignal.set_error(e)
  # end
  # # Manually completing the transaction here.
  # # Manually stopping AppSignal here
  # ```
  # 
  # In a Rails application
  # ```ruby
  # class SomeController < ApplicationController
  #   # The AppSignal transaction is created by our integration for you.
  #   def create
  #     # Do something that breaks
  #   rescue => e
  #     Appsignal.set_error(e)
  #   end
  # end
  # ```
  # 
  # Add more metadata to transaction
  # ```ruby
  # Appsignal.set_error(e) do
  #   Appsignal.set_namespace("my_namespace")
  #   Appsignal.set_action("my_action_name")
  #   Appsignal.add_params(:search_query => params[:search_query])
  #   Appsignal.add_tags(:key => "value")
  # end
  # ```
  # 
  # _@see_ `https://docs.appsignal.com/ruby/instrumentation/exception-handling.html` — Exception handling guide
  sig { params(exception: Exception, blk: T.proc.params(transaction: Transaction).void).void }
  def self.set_error(exception, &blk); end

  # Report an error to AppSignal.
  # 
  # If a transaction is currently active, it will report the error on the
  # current transaction. If no transaction is active, it will report the
  # error on a new transaction.
  # 
  # If a transaction is active and the transaction already has an error
  # reported on it, it will report multiple errors, up to a maximum of 10
  # errors.
  # 
  # If a block is given to this method, the metadata set in this block will
  # only be applied to the transaction created for the given error. The
  # block will be called when the transaction is completed, which can be
  # much later than when {#report_error} is called.
  # 
  # **Note**: If AppSignal is not active, no error is reported.
  # 
  # **Note**: If the given exception argument is not an Exception subclass,
  # it will not be reported.
  # 
  # _@param_ `exception` — The error to add to the current transaction.
  # 
  # ```ruby
  # class SomeController < ApplicationController
  #   def create
  #     # Do something that breaks
  #   rescue => error
  #     Appsignal.report_error(error)
  #   end
  # end
  # ```
  # 
  # Add more metadata to transaction
  # ```ruby
  # Appsignal.report_error(error) do
  #   Appsignal.set_namespace("my_namespace")
  #   Appsignal.set_action("my_action_name")
  #   Appsignal.add_params(:search_query => params[:search_query])
  #   Appsignal.add_tags(:key => "value")
  # end
  # ```
  # 
  # _@see_ `https://docs.appsignal.com/ruby/instrumentation/exception-handling.html` — Exception handling guide
  sig { params(exception: Exception, block: T.proc.params(transaction: Transaction).void).void }
  def self.report_error(exception, &block); end

  # Set a custom action name for the current transaction.
  # 
  # When using an integration such as the Rails or Sinatra AppSignal will
  # try to find the action name from the controller or endpoint for you.
  # 
  # If you want to customize the action name as it appears on AppSignal.com
  # you can use this method. This overrides the action name AppSignal
  # generates in an integration.
  # 
  # _@param_ `action`
  # 
  # in a Rails controller
  # ```ruby
  # class SomeController < ApplicationController
  #   before_action :set_appsignal_action
  # 
  #   def set_appsignal_action
  #     Appsignal.set_action("DynamicController#dynamic_method")
  #   end
  # end
  # ```
  sig { params(action: String).void }
  def self.set_action(action); end

  # Set a custom namespace for the current transaction.
  # 
  # When using an integration such as Rails or Sidekiq AppSignal will try
  # to find a appropriate namespace for the transaction.
  # 
  # A Rails controller will be automatically put in the "http_request"
  # namespace, while a Sidekiq background job is put in the
  # "background_job" namespace.
  # 
  # Note: The "http_request" namespace gets transformed on AppSignal.com to
  # "Web" and "background_job" gets transformed to "Background".
  # 
  # If you want to customize the namespace in which transactions appear you
  # can use this method. This overrides the namespace AppSignal uses by
  # default.
  # 
  # A common request we've seen is to split the administration panel from
  # the main application.
  # 
  # _@param_ `namespace`
  # 
  # create a custom admin namespace
  # ```ruby
  # class AdminController < ApplicationController
  #   before_action :set_appsignal_namespace
  # 
  #   def set_appsignal_namespace
  #     Appsignal.set_namespace("admin")
  #   end
  # end
  # ```
  # 
  # _@see_ `https://docs.appsignal.com/guides/namespaces.html` — Grouping with namespaces guide
  sig { params(namespace: String).void }
  def self.set_namespace(namespace); end

  # Add custom data to the current transaction.
  # 
  # Add extra information about the request or background that cannot be
  # expressed in tags, like nested data structures.
  # 
  # If the root data type changes between calls of this method, the last
  # method call is stored.
  # 
  # _@param_ `data` — Custom data to add to the transaction.
  # 
  # Add Hash data
  # ```ruby
  # Appsignal.add_custom_data(:user => { :locale => "en" })
  # ```
  # 
  # Merges Hash data
  # ```ruby
  # Appsignal.add_custom_data(:abc => "def")
  # Appsignal.add_custom_data(:xyz => "...")
  # # The custom data is: { :abc => "def", :xyz => "..." }
  # ```
  # 
  # Add Array data
  # ```ruby
  # Appsignal.add_custom_data([
  #   "array with data",
  #   "other value",
  #   :options => { :verbose => true }
  # ])
  # ```
  # 
  # Merges Array data
  # ```ruby
  # Appsignal.add_custom_data([1, 2, 3])
  # Appsignal.add_custom_data([4, 5, 6])
  # # The custom data is: [1, 2, 3, 4, 5, 6]
  # ```
  # 
  # Mixing of root data types is not supported
  # ```ruby
  # Appsignal.add_custom_data(:abc => "def")
  # Appsignal.add_custom_data([1, 2, 3])
  # # The custom data is: [1, 2, 3]
  # ```
  # 
  # _@see_ `https://docs.appsignal.com/guides/custom-data/sample-data.html` — Sample data guide
  sig { params(data: T.any(T::Hash[Object, Object], T::Array[Object])).void }
  def self.add_custom_data(data); end

  # Add tags to the current transaction.
  # 
  # Tags are extra bits of information that are added to transaction and
  # appear on sample details pages on AppSignal.com.
  # 
  # When this method is called multiple times, it will merge the tags.
  # 
  # _@param_ `tags` — Collection of tags to add to the transaction.
  # 
  # ```ruby
  # Appsignal.add_tags(:locale => "en", :user_id => 1)
  # Appsignal.add_tags("locale" => "en")
  # Appsignal.add_tags("user_id" => 1)
  # ```
  # 
  # Nested hashes are not supported
  # ```ruby
  # # Bad
  # Appsignal.add_tags(:user => { :locale => "en" })
  # ```
  # 
  # in a Rails controller
  # ```ruby
  # class SomeController < ApplicationController
  #   before_action :add_appsignal_tags
  # 
  #   def add_appsignal_tags
  #     Appsignal.add_tags(:locale => I18n.locale)
  #   end
  # end
  # ```
  # 
  # _@see_ `https://docs.appsignal.com/ruby/instrumentation/tagging.html` — Tagging guide
  sig { params(tags: T::Hash[Object, Object]).void }
  def self.add_tags(tags = {}); end

  # Add parameters to the current transaction.
  # 
  # Parameters are automatically added by most of our integrations. It
  # should not be necessary to call this method unless you want to report
  # different parameters.
  # 
  # This method accepts both Hash and Array parameter types:
  # - Hash parameters will be merged when called multiple times
  # - Array parameters will be concatenated when called multiple times
  # - Mixing Hash and Array types will use the latest type (and log a warning)
  # 
  # To filter parameters, see our parameter filtering guide.
  # 
  # When both the `params` argument and a block is given to this method,
  # the block is leading and the argument will _not_ be used.
  # 
  # _@param_ `params` — The parameters to add to the transaction.
  # 
  # Add Hash parameters
  # ```ruby
  # Appsignal.add_params("param1" => "value1")
  # # The parameters include: { "param1" => "value1" }
  # ```
  # 
  # Add Array parameters
  # ```ruby
  # Appsignal.add_params(["item1", "item2"])
  # # The parameters include: ["item1", "item2"]
  # ```
  # 
  # Calling `add_params` multiple times with Hashes merges values
  # ```ruby
  # Appsignal.add_params("param1" => "value1")
  # Appsignal.add_params("param2" => "value2")
  # # The parameters include:
  # # { "param1" => "value1", "param2" => "value2" }
  # ```
  # 
  # Calling `add_params` multiple times with Arrays concatenates values
  # ```ruby
  # Appsignal.add_params(["item1"])
  # Appsignal.add_params(["item2"])
  # # The parameters include: ["item1", "item2"]
  # ```
  # 
  # _@see_ `https://docs.appsignal.com/guides/custom-data/sample-data.html` — Sample data guide
  # 
  # _@see_ `https://docs.appsignal.com/guides/filter-data/filter-parameters.html` — Parameter filtering guide
  sig { params(params: T.nilable(T.any(T::Hash[String, Object], T::Array[Object])), block: T.proc.returns(T.any(T::Hash[String, Object], T::Array[Object]))).void }
  def self.add_params(params = nil, &block); end

  # Mark the parameters sample data to be set as an empty value.
  # 
  # Use this helper to unset request parameters / background job arguments
  # and not report any for this transaction.
  # 
  # If parameters would normally be added by AppSignal instrumentations of
  # libraries, these parameters will not be added to the Transaction.
  # 
  # Calling {#add_params} after this helper will add new parameters to the
  # transaction.
  # 
  # _@see_ `Transaction#set_empty_params!`
  # 
  # _@see_ `Transaction#set_params_if_nil`
  sig { void }
  def self.set_empty_params!; end

  # Add session data to the current transaction.
  # 
  # Session data is automatically added by most of our integrations. It
  # should not be necessary to call this method unless you want to report
  # different session data.
  # 
  # To filter session data, see our session data filtering guide.
  # 
  # When both the `session_data` argument and a block is given to this
  # method, the bock is leading and the argument will _not_ be used.
  # 
  # _@param_ `session_data` — The session data to add to the transaction.
  # 
  # Add session data
  # ```ruby
  # Appsignal.add_session_data("session" => "data")
  # # The session data will include:
  # # { "session" => "data" }
  # ```
  # 
  # Calling `add_session_data` multiple times merge the values
  # ```ruby
  # Appsignal.add_session_data("session" => "data")
  # Appsignal.add_session_data("other" => "value")
  # # The session data will include:
  # # { "session" => "data", "other" => "value" }
  # ```
  # 
  # _@see_ `https://docs.appsignal.com/guides/custom-data/sample-data.html` — Sample data guide
  # 
  # _@see_ `https://docs.appsignal.com/guides/filter-data/filter-session-data.html` — Session data filtering guide
  sig { params(session_data: T.nilable(T::Hash[String, Object]), block: T.proc.returns(T::Hash[String, Object])).void }
  def self.add_session_data(session_data = nil, &block); end

  # Add request headers to the current transaction.
  # 
  # Request headers are automatically added by most of our integrations. It
  # should not be necessary to call this method unless you want to also
  # report different request headers.
  # 
  # To filter request headers, see our request header filtering guide.
  # 
  # When both the `request_headers` argument and a block is given to this
  # method, the block is leading and the argument will _not_ be used.
  # 
  # _@param_ `headers` — The request headers to add to the transaction.
  # 
  # Add request headers
  # ```ruby
  # Appsignal.add_headers("PATH_INFO" => "/some-path")
  # # The request headers will include:
  # # { "PATH_INFO" => "/some-path" }
  # ```
  # 
  # Calling `add_headers` multiple times merge the values
  # ```ruby
  # Appsignal.add_headers("PATH_INFO" => "/some-path")
  # Appsignal.add_headers("HTTP_USER_AGENT" => "Firefox")
  # # The request headers will include:
  # # { "PATH_INFO" => "/some-path", "HTTP_USER_AGENT" => "Firefox" }
  # ```
  # 
  # _@see_ `https://docs.appsignal.com/guides/custom-data/sample-data.html` — Sample data guide
  # 
  # _@see_ `https://docs.appsignal.com/guides/filter-data/filter-headers.html` — Request headers filtering guide
  sig { params(headers: T.nilable(T::Hash[String, Object]), block: T.proc.returns(T::Hash[String, Object])).void }
  def self.add_headers(headers = nil, &block); end

  # Add breadcrumbs to the transaction.
  # 
  # Breadcrumbs can be used to trace what path a user has taken
  # before encountering an error.
  # 
  # Only the last 20 added breadcrumbs will be saved.
  # 
  # _@param_ `category` — category of breadcrumb e.g. "UI", "Network", "Navigation", "Console".
  # 
  # _@param_ `action` — name of breadcrumb e.g "The user clicked a button", "HTTP 500 from http://blablabla.com"
  # 
  # _@param_ `message` — optional message in string format
  # 
  # _@param_ `metadata` — key/value metadata in <string, string> format
  # 
  # _@param_ `time` — time of breadcrumb, should respond to `.to_i` defaults to `Time.now.utc`
  # 
  # ```ruby
  # Appsignal.add_breadcrumb(
  #   "Navigation",
  #   "http://blablabla.com",
  #   "",
  #   { :response => 200 },
  #   Time.now.utc
  # )
  # Appsignal.add_breadcrumb(
  #   "Network",
  #   "[GET] http://blablabla.com",
  #   "",
  #   { :response => 500 }
  # )
  # Appsignal.add_breadcrumb(
  #   "UI",
  #   "closed modal(change_password)",
  #   "User closed modal without actions"
  # )
  # ```
  # 
  # _@see_ `https://docs.appsignal.com/ruby/instrumentation/breadcrumbs.html` — Breadcrumb reference
  sig do
    params(
      category: String,
      action: String,
      message: String,
      metadata: T::Hash[String, String],
      time: Time
    ).void
  end
  def self.add_breadcrumb(category, action, message = "", metadata = {}, time = Time.now.utc); end

  # Instrument helper for AppSignal.
  # 
  # For more help, read our custom instrumentation guide, listed under "See
  # also".
  # 
  # _@param_ `name` — Name of the instrumented event. Read our event naming guide listed under "See also".
  # 
  # _@param_ `title` — Human readable name of the event.
  # 
  # _@param_ `body` — Value of importance for the event, such as the server against an API call is made.
  # 
  # _@param_ `body_format` — Enum for the type of event that is instrumented. Accepted values are {EventFormatter::DEFAULT} and {EventFormatter::SQL_BODY_FORMAT}, but we recommend you use {.instrument_sql} instead of {EventFormatter::SQL_BODY_FORMAT}.
  # 
  # _@return_ — Returns the block's return value.
  # 
  # Simple instrumentation
  # ```ruby
  # Appsignal.instrument("fetch.issue_fetcher") do
  #   # To be instrumented code
  # end
  # ```
  # 
  # Instrumentation with title and body
  # ```ruby
  # Appsignal.instrument(
  #   "fetch.issue_fetcher",
  #   "Fetching issue",
  #   "GitHub API"
  # ) do
  #   # To be instrumented code
  # end
  # ```
  # 
  # _@see_ `.instrument_sql`
  # 
  # _@see_ `https://docs.appsignal.com/ruby/instrumentation/instrumentation.html` — AppSignal custom instrumentation guide
  # 
  # _@see_ `https://docs.appsignal.com/api/event-names.html` — AppSignal event naming guide
  sig do
    params(
      name: String,
      title: T.nilable(String),
      body: T.nilable(String),
      body_format: Integer,
      block: T.untyped
    ).returns(Object)
  end
  def self.instrument(name, title = nil, body = nil, body_format = Appsignal::EventFormatter::DEFAULT, &block); end

  # Instrumentation helper for SQL queries.
  # 
  # This helper filters out values from SQL queries so you don't have to.
  # 
  # _@param_ `name` — Name of the instrumented event. Read our event naming guide listed under "See also".
  # 
  # _@param_ `title` — Human readable name of the event.
  # 
  # _@param_ `body` — SQL query that's being executed.
  # 
  # _@return_ — Returns the block's return value.
  # 
  # SQL query instrumentation
  # ```ruby
  # body = "SELECT * FROM ..."
  # Appsignal.instrument_sql("perform.query", nil, body) do
  #   # To be instrumented code
  # end
  # ```
  # 
  # SQL query instrumentation
  # ```ruby
  # body = "WHERE email = 'foo@..'"
  # Appsignal.instrument_sql("perform.query", nil, body) do
  #   # query value will replace 'foo..' with a question mark `?`.
  # end
  # ```
  # 
  # _@see_ `.instrument`
  # 
  # _@see_ `https://docs.appsignal.com/ruby/instrumentation/instrumentation.html` — AppSignal custom instrumentation guide
  # 
  # _@see_ `https://docs.appsignal.com/api/event-names.html` — AppSignal event naming guide
  sig do
    params(
      name: String,
      title: T.nilable(String),
      body: T.nilable(String),
      block: T.untyped
    ).returns(Object)
  end
  def self.instrument_sql(name, title = nil, body = nil, &block); end

  # Convenience method for ignoring instrumentation events in a block of
  # code.
  # 
  # - This helper ignores events, like those created
  #   `Appsignal.instrument`, within this block.
  #   This includes custom instrumentation and events recorded by AppSignal
  #   integrations for requests, database queries, view rendering, etc.
  # - The time spent in the block is still reported on the transaction.
  # - Errors and metrics are reported from within this block.
  # 
  # _@return_ — Returns the return value of the block.
  # Return nil if the block returns nil or no block is given.
  # 
  # ```ruby
  # Appsignal.instrument "my_event.my_group" do
  #   # Complex code here
  # end
  # Appsignal.ignore_instrumentation_events do
  #   Appsignal.instrument "my_ignored_event.my_ignored_group" do
  #     # Complex code here
  #   end
  # end
  # 
  # # Only the "my_event.my_group" instrumentation event is reported.
  # ```
  # 
  # _@see_ `https://docs.appsignal.com/ruby/instrumentation/ignore-instrumentation.html` — Ignore instrumentation guide
  sig { params(blk: T.proc.returns(Object)).returns(T.nilable(Object)) }
  def self.ignore_instrumentation_events(&blk); end

  # {Appsignal::Demo} is a way to send demonstration / test samples for a
  # exception and a performance issue.
  # 
  # @example Send example transactions
  #   Appsignal::Demo.transmit
  # 
  # @since 2.0.0
  # @see Appsignal::CLI::Demo
  # @api private
  class Demo
    # Starts AppSignal and transmits the demonstration samples to AppSignal
    # using the loaded configuration.
    # 
    # _@return_ — - returns `false` if Appsignal is not active.
    sig { returns(T::Boolean) }
    def self.transmit; end

    # Error type used to create demonstration exception.
    class TestError < StandardError
    end
  end

  class Config
    # Check if the configuration is valid.
    # 
    # _@return_ — True if the configuration is valid, false otherwise.
    sig { returns(T::Boolean) }
    def valid?; end

    # Check if AppSignal is active for the current environment.
    # 
    # _@return_ — True if active for the current environment.
    sig { returns(T::Boolean) }
    def active_for_env?; end

    # Check if AppSignal is active.
    # 
    # _@return_ — True if valid and active for the current environment.
    sig { returns(T::Boolean) }
    def active?; end

    sig { returns(T::Boolean) }
    def yml_config_file?; end

    # Configuration DSL for use in configuration blocks.
    # 
    # This class provides a Domain Specific Language for configuring AppSignal
    # within the `Appsignal.configure` block. It provides getter and setter
    # methods for all configuration options.
    # 
    # @example Using the configuration DSL
    #   Appsignal.configure do |config|
    #     config.name = "My App"
    #     config.active = true
    #     config.push_api_key = "your-api-key"
    #     config.ignore_actions = ["StatusController#health"]
    #   end
    # 
    # @see AppSignal Ruby gem configuration
    #   https://docs.appsignal.com/ruby/configuration.html
    class ConfigDSL
      # Returns the application's root path.
      # 
      # _@return_ — The root path of the application
      sig { returns(String) }
      def app_path; end

      # Returns the current environment name.
      # 
      # _@return_ — The environment name (e.g., "production", "development")
      sig { returns(String) }
      def env; end

      # Returns true if the given environment name matches the loaded
      # environment name.
      # 
      # _@param_ `given_env`
      sig { params(given_env: T.any(String, Symbol)).returns(T.any(TrueClass, FalseClass)) }
      def env?(given_env); end

      # Activates AppSignal if the current environment matches any of the given environments.
      # 
      # _@param_ `envs` — List of environment names to activate for
      # 
      # _@return_ — true if AppSignal was activated, false otherwise
      # 
      # Activate for production and staging
      # ```ruby
      # config.activate_if_environment(:production, :staging)
      # ```
      sig { params(envs: T::Array[T.any(String, Symbol)]).returns(T::Boolean) }
      def activate_if_environment(*envs); end

      # _@return_ — Error reporting mode for ActiveJob ("all", "discard" or "none")
      sig { returns(String) }
      attr_accessor :activejob_report_errors

      # _@return_ — The application name
      sig { returns(String) }
      attr_accessor :name

      # _@return_ — The host to the agent binds to for its HTTP server
      sig { returns(String) }
      attr_accessor :bind_address

      # _@return_ — Path to the CA certificate file
      sig { returns(String) }
      attr_accessor :ca_file_path

      # _@return_ — Override for the detected hostname
      sig { returns(String) }
      attr_accessor :hostname

      # _@return_ — Role of the host for grouping in metrics
      sig { returns(String) }
      attr_accessor :host_role

      # _@return_ — HTTP proxy URL
      sig { returns(String) }
      attr_accessor :http_proxy

      # _@return_ — Log destination ("file" or "stdout")
      sig { returns(String) }
      attr_accessor :log

      # _@return_ — AppSignal internal logger
      # log level ("error", "warn", "info", "debug", "trace")
      sig { returns(String) }
      attr_accessor :log_level

      # _@return_ — Path to the log directory
      sig { returns(String) }
      attr_accessor :log_path

      # _@return_ — Endpoint for log transmission
      sig { returns(String) }
      attr_accessor :logging_endpoint

      # _@return_ — Push API endpoint URL
      sig { returns(String) }
      attr_accessor :endpoint

      # _@return_ — AppSignal Push API key
      sig { returns(String) }
      attr_accessor :push_api_key

      # _@return_ — Error reporting mode for Sidekiq ("all", "discard" or "none")
      sig { returns(String) }
      attr_accessor :sidekiq_report_errors

      # _@return_ — Port for StatsD metrics
      sig { returns(String) }
      attr_accessor :statsd_port

      # _@return_ — Port for Nginx metrics collection
      sig { returns(String) }
      attr_accessor :nginx_port

      # _@return_ — Override for the agent working directory
      sig { returns(String) }
      attr_accessor :working_directory_path

      # _@return_ — Application revision identifier
      sig { returns(String) }
      attr_accessor :revision

      # _@return_ — Activate AppSignal for the loaded environment
      sig { returns(T::Boolean) }
      attr_accessor :active

      # _@return_ — Configure whether allocation tracking is enabled
      sig { returns(T::Boolean) }
      attr_accessor :enable_allocation_tracking

      # _@return_ — Configure whether the at_exit reporter is enabled
      sig { returns(T::Boolean) }
      attr_accessor :enable_at_exit_reporter

      # _@return_ — Configure whether host metrics collection is enabled
      sig { returns(T::Boolean) }
      attr_accessor :enable_host_metrics

      # _@return_ — Configure whether minutely probes are enabled
      sig { returns(T::Boolean) }
      attr_accessor :enable_minutely_probes

      # _@return_ — Configure whether the StatsD metrics endpoint on the agent is enabled
      sig { returns(T::Boolean) }
      attr_accessor :enable_statsd

      # _@return_ — Configure whether the agent's NGINX metrics endpoint is enabled
      sig { returns(T::Boolean) }
      attr_accessor :enable_nginx_metrics

      # _@return_ — Configure whether the GVL global timer instrumentationis enabled
      sig { returns(T::Boolean) }
      attr_accessor :enable_gvl_global_timer

      # _@return_ — Configure whether GVL waiting threads instrumentation is enabled
      sig { returns(T::Boolean) }
      attr_accessor :enable_gvl_waiting_threads

      # _@return_ — Configure whether Rails error reporter integration is enabled
      sig { returns(T::Boolean) }
      attr_accessor :enable_rails_error_reporter

      # _@return_ — Configure whether Rake performance instrumentation is enabled
      sig { returns(T::Boolean) }
      attr_accessor :enable_rake_performance_instrumentation

      # _@return_ — Configure whether files created by AppSignal should be world accessible
      sig { returns(T::Boolean) }
      attr_accessor :files_world_accessible

      # _@return_ — Configure whether to instrument requests made with the http.rb gem
      sig { returns(T::Boolean) }
      attr_accessor :instrument_http_rb

      # _@return_ — Configure whether to instrument requests made with Net::HTTP
      sig { returns(T::Boolean) }
      attr_accessor :instrument_net_http

      # _@return_ — Configure whether to instrument the Ownership gem
      sig { returns(T::Boolean) }
      attr_accessor :instrument_ownership

      # _@return_ — Configure whether to instrument Redis queries
      sig { returns(T::Boolean) }
      attr_accessor :instrument_redis

      # _@return_ — Configure whether to instrument Sequel queries
      sig { returns(T::Boolean) }
      attr_accessor :instrument_sequel

      # _@return_ — Configure whether the Ownership gem instrumentation should set namespace
      sig { returns(T::Boolean) }
      attr_accessor :ownership_set_namespace

      # _@return_ — Configure whether the application is running in a container
      sig { returns(T::Boolean) }
      attr_accessor :running_in_container

      # _@return_ — Configure whether to send environment metadata
      sig { returns(T::Boolean) }
      attr_accessor :send_environment_metadata

      # _@return_ — Configure whether to send request parameters
      sig { returns(T::Boolean) }
      attr_accessor :send_params

      # _@return_ — Configure whether to send request session data
      sig { returns(T::Boolean) }
      attr_accessor :send_session_data

      # _@return_ — Custom DNS servers to use
      sig { returns(T::Array[String]) }
      attr_accessor :dns_servers

      # _@return_ — Metadata keys to filter from trace data
      sig { returns(T::Array[String]) }
      attr_accessor :filter_metadata

      # _@return_ — Keys of parameter to filter
      sig { returns(T::Array[String]) }
      attr_accessor :filter_parameters

      # _@return_ — Request session data keys to filter
      sig { returns(T::Array[String]) }
      attr_accessor :filter_session_data

      # _@return_ — Ignore traces by action names
      sig { returns(T::Array[String]) }
      attr_accessor :ignore_actions

      # _@return_ — List of errors to not report
      sig { returns(T::Array[String]) }
      attr_accessor :ignore_errors

      # _@return_ — Ignore log messages by substrings
      sig { returns(T::Array[String]) }
      attr_accessor :ignore_logs

      # _@return_ — Ignore traces by namespaces
      sig { returns(T::Array[String]) }
      attr_accessor :ignore_namespaces

      # _@return_ — HTTP request headers to include in error reports
      sig { returns(T::Array[String]) }
      attr_accessor :request_headers

      # _@return_ — CPU count override for metrics collection
      sig { returns(Float) }
      attr_accessor :cpu_count
    end
  end

  # Logger that flushes logs to the AppSignal logging service.
  # 
  # @see https://docs.appsignal.com/logging/platforms/integrations/ruby.html
  #   AppSignal Ruby logging documentation.
  class Logger < ::Logger
    # Create a new logger instance
    # 
    # _@param_ `group` — Name of the group for this logger.
    # 
    # _@param_ `level` — Minimum log level to report. Log lines below this level will be ignored.
    # 
    # _@param_ `format` — Format to use to parse log line attributes.
    # 
    # _@param_ `attributes` — Default attributes for all log lines.
    sig do
      params(
        group: String,
        level: Integer,
        format: Integer,
        attributes: T::Hash[String, String]
      ).void
    end
    def initialize(group, level: INFO, format: PLAINTEXT, attributes: {}); end

    # Sets the formatter for this logger and all broadcasted loggers.
    # 
    # _@param_ `formatter` — The formatter to use for log messages.
    sig { params(formatter: Proc).returns(Proc) }
    def formatter=(formatter); end

    # Log a debug level message
    # 
    # _@param_ `message` — Message to log
    # 
    # _@param_ `attributes` — Attributes to tag the log with
    sig { params(message: T.nilable(String), attributes: T::Hash[String, Object], block: T.untyped).void }
    def debug(message = nil, attributes = {}, &block); end

    # Log an info level message
    # 
    # _@param_ `message` — Message to log
    # 
    # _@param_ `attributes` — Attributes to tag the log with
    sig { params(message: T.nilable(String), attributes: T::Hash[String, Object], block: T.untyped).void }
    def info(message = nil, attributes = {}, &block); end

    # Log a warn level message
    # 
    # _@param_ `message` — Message to log
    # 
    # _@param_ `attributes` — Attributes to tag the log with
    sig { params(message: T.nilable(String), attributes: T::Hash[String, Object], block: T.untyped).void }
    def warn(message = nil, attributes = {}, &block); end

    # Log an error level message
    # 
    # _@param_ `message` — Message to log
    # 
    # _@param_ `attributes` — Attributes to tag the log with
    sig { params(message: T.nilable(T.any(String, Exception)), attributes: T::Hash[String, Object], block: T.untyped).void }
    def error(message = nil, attributes = {}, &block); end

    # Log a fatal level message
    # 
    # _@param_ `message` — Message to log
    # 
    # _@param_ `attributes` — Attributes to tag the log with
    sig { params(message: T.nilable(T.any(String, Exception)), attributes: T::Hash[String, Object], block: T.untyped).void }
    def fatal(message = nil, attributes = {}, &block); end

    # Log an info level message
    # 
    # Returns the number of characters written.
    # 
    # _@param_ `message` — Message to log
    sig { params(message: String).returns(Integer) }
    def <<(message); end

    # Temporarily silences the logger to a specified level while executing a block.
    # 
    # When using ActiveSupport::TaggedLogging without the broadcast feature,
    # the passed logger is required to respond to the `silence` method.
    # 
    # Reference links:
    # 
    # - https://github.com/rails/rails/blob/e11ebc04cfbe41c06cdfb70ee5a9fdbbd98bb263/activesupport/lib/active_support/logger.rb#L60-L76
    # - https://github.com/rails/rails/blob/e11ebc04cfbe41c06cdfb70ee5a9fdbbd98bb263/activesupport/lib/active_support/logger_silence.rb
    # 
    # _@param_ `severity` — The minimum severity level to log during the block.
    # 
    # _@return_ — The return value of the block.
    sig { params(severity: Integer, block: T.untyped).returns(Object) }
    def silence(severity = ERROR, &block); end

    # Adds a logger to broadcast log messages to.
    # 
    # _@param_ `logger` — The logger to add to the broadcast list.
    sig { params(logger: Logger).returns(T::Array[Logger]) }
    def broadcast_to(logger); end

    # Logging severity threshold
    sig { returns(Integer) }
    attr_reader :level
  end

  module Probes
    # Register a new minutely probe.
    # 
    # Supported probe types are:
    # 
    # - Lambda - A lambda is an object that listens to a `call` method call.
    #   This `call` method is called every minute.
    # - Class - A class object is an object that listens to a `new` and
    #   `call` method call. The `new` method is called when the minutely
    #   probe thread is started to initialize all probes. This allows probes
    #   to load dependencies once beforehand. Their `call` method is called
    #   every minute.
    # - Class instance - A class instance object is an object that listens to
    #   a `call` method call. The `call` method is called every minute.
    # 
    # _@param_ `name` — Name of the probe. Can be used with {ProbeCollection#[]}. This name will be used in errors in the log and allows overwriting of probes by registering new ones with the same name.
    # 
    # _@param_ `probe` — Any object that listens to the `call` method will be used as a probe.
    # 
    # Register a new probe
    # ```ruby
    # Appsignal::Probes.register :my_probe, lambda {}
    # ```
    # 
    # Overwrite an existing registered probe
    # ```ruby
    # Appsignal::Probes.register :my_probe, lambda {}
    # Appsignal::Probes.register :my_probe, lambda { puts "hello" }
    # ```
    # 
    # Add a lambda as a probe
    # ```ruby
    # Appsignal::Probes.register :my_probe, lambda { puts "hello" }
    # # "hello" # printed every minute
    # ```
    # 
    # Add a probe instance
    # ```ruby
    # class MyProbe
    #   def initialize
    #     puts "started"
    #   end
    # 
    #   def call
    #     puts "called"
    #   end
    # end
    # 
    # Appsignal::Probes.register :my_probe, MyProbe.new
    # # "started" # printed immediately
    # # "called" # printed every minute
    # ```
    # 
    # Add a probe class
    # ```ruby
    # class MyProbe
    #   def initialize
    #     # Add things that only need to be done on start up for this probe
    #     require "some/library/dependency"
    #     @cache = {} # initialize a local cache variable
    #     puts "started"
    #   end
    # 
    #   def call
    #     puts "called"
    #   end
    # end
    # 
    # Appsignal::Probes.register :my_probe, MyProbe
    # Appsignal::Probes.start # This is called for you
    # # "started" # Printed on Appsignal::Probes.start
    # # "called" # Repeated every minute
    # ```
    sig { params(name: T.any(Symbol, String), probe: Object).void }
    def self.register(name, probe); end

    # Unregister a probe that's registered with {register}.
    # Can also be used to unregister automatically registered probes by the
    # gem.
    # 
    # _@param_ `name` — Name of the probe used to {register} the probe.
    # 
    # Unregister probes
    # ```ruby
    # # First register a probe
    # Appsignal::Probes.register :my_probe, lambda {}
    # 
    # # Then unregister a probe if needed
    # Appsignal::Probes.unregister :my_probe
    # ```
    sig { params(name: T.any(Symbol, String)).void }
    def self.unregister(name); end

    sig { void }
    def self.start; end

    # Returns if the probes thread has been started. If the value is false or
    # nil, it has not been started yet.
    sig { returns(T.nilable(T::Boolean)) }
    def self.started?; end

    # Stop the minutely probes mechanism. Stop the thread and clear all probe
    # instances.
    sig { void }
    def self.stop; end
  end

  module CheckIn
    # Track cron check-ins.
    # 
    # Track the execution of scheduled processes by sending a cron check-in.
    # 
    # To track the duration of a piece of code, pass a block to {.cron}
    # to report both when the process starts, and when it finishes.
    # 
    # If an exception is raised within the block, the finish event will not
    # be reported, triggering a notification about the missing cron check-in.
    # The exception will bubble outside of the cron check-in block.
    # 
    # _@param_ `identifier` — identifier of the cron check-in to report.
    # 
    # _@return_ — returns the block value.
    # 
    # Send a cron check-in
    # ```ruby
    # Appsignal::CheckIn.cron("send_invoices")
    # ```
    # 
    # Send a cron check-in with duration
    # ```ruby
    # Appsignal::CheckIn.cron("send_invoices") do
    #   # your code
    # end
    # ```
    # 
    # _@see_ `https://docs.appsignal.com/check-ins/cron`
    sig { params(identifier: String, blk: T.proc.returns(Object)).returns(Object) }
    def self.cron(identifier, &blk); end

    # Track heartbeat check-ins.
    # 
    # Track the execution of long-lived processes by sending a heartbeat
    # check-in.
    # 
    # _@param_ `identifier` — identifier of the heartbeat check-in to report.
    # 
    # _@param_ `continuous` — whether the heartbeats should be sent continuously during the lifetime of the process. Defaults to `false`.
    # 
    # Send a heartbeat check-in
    # ```ruby
    # Appsignal::CheckIn.heartbeat("main_loop")
    # ```
    # 
    # _@see_ `https://docs.appsignal.com/check-ins/heartbeat`
    sig { params(identifier: String, continuous: T::Boolean).void }
    def self.heartbeat(identifier, continuous: false); end
  end

  class Transaction
    HTTP_REQUEST = T.let("http_request", T.untyped)
    BACKGROUND_JOB = T.let("background_job", T.untyped)

    # Create a new transaction and set it as the currently active
    # transaction.
    # 
    # _@param_ `namespace` — Namespace of the to be created transaction.
    sig { params(namespace: String).returns(Transaction) }
    def self.create(namespace); end

    # Returns currently active transaction or a {NilTransaction} if none is
    # active.
    # 
    # _@see_ `.current?`
    sig { returns(T.any(Appsignal::Transaction, Appsignal::Transaction::NilTransaction)) }
    def self.current; end

    # Returns if any transaction is currently active or not. A
    # {NilTransaction} is not considered an active transaction.
    # 
    # _@see_ `.current`
    sig { returns(T::Boolean) }
    def self.current?; end

    # Complete the currently active transaction and unset it as the active
    # transaction.
    sig { void }
    def self.complete_current!; end

    # Add parameters to the transaction.
    # 
    # When this method is called multiple times, it will merge the request parameters.
    # 
    # When both the `given_params` and a block is given to this method, the
    # block is leading and the argument will _not_ be used.
    # 
    # _@param_ `given_params` — The parameters to set on the transaction.
    # 
    # _@see_ `Helpers::Instrumentation#add_params`
    # 
    # _@see_ `https://docs.appsignal.com/guides/custom-data/sample-data.html` — Sample data guide
    sig { params(given_params: T.nilable(T.any(T::Hash[String, Object], T::Array[Object])), block: T.proc.returns(T.any(T::Hash[String, Object], T::Array[Object]))).void }
    def add_params(given_params = nil, &block); end

    # Add tags to the transaction.
    # 
    # When this method is called multiple times, it will merge the tags.
    # 
    # _@param_ `given_tags` — Collection of tags.
    # 
    # _@see_ `Helpers::Instrumentation#add_tags`
    # 
    # _@see_ `https://docs.appsignal.com/ruby/instrumentation/tagging.html` — Tagging guide
    sig { params(given_tags: T::Hash[String, Object]).void }
    def add_tags(given_tags = {}); end

    # Add session data to the transaction.
    # 
    # When this method is called multiple times, it will merge the session data.
    # 
    # When both the `given_session_data` and a block is given to this method,
    # the block is leading and the argument will _not_ be used.
    # 
    # _@param_ `given_session_data` — A hash containing session data.
    # 
    # _@see_ `Helpers::Instrumentation#add_session_data`
    # 
    # _@see_ `https://docs.appsignal.com/guides/custom-data/sample-data.html` — Sample data guide
    sig { params(given_session_data: T.nilable(T::Hash[String, Object]), block: T.proc.returns(T::Hash[String, Object])).void }
    def add_session_data(given_session_data = nil, &block); end

    # Add headers to the transaction.
    # 
    # _@param_ `given_headers` — A hash containing headers.
    # 
    # _@see_ `Helpers::Instrumentation#add_headers`
    # 
    # _@see_ `https://docs.appsignal.com/guides/custom-data/sample-data.html` — Sample data guide
    sig { params(given_headers: T.nilable(T::Hash[String, Object]), block: T.proc.returns(T::Hash[String, Object])).void }
    def add_headers(given_headers = nil, &block); end

    # Add custom data to the transaction.
    # 
    # _@param_ `data` — Custom data to add to the transaction.
    # 
    # _@see_ `Helpers::Instrumentation#add_custom_data`
    # 
    # _@see_ `https://docs.appsignal.com/guides/custom-data/sample-data.html` — Sample data guide
    sig { params(data: T.any(T::Hash[Object, Object], T::Array[Object])).void }
    def add_custom_data(data); end

    # Add breadcrumbs to the transaction.
    # 
    # _@param_ `category` — category of breadcrumb e.g. "UI", "Network", "Navigation", "Console".
    # 
    # _@param_ `action` — name of breadcrumb e.g "The user clicked a button", "HTTP 500 from http://blablabla.com"
    # 
    # _@param_ `message` — optional message in string format
    # 
    # _@param_ `metadata` — key/value metadata in <string, string> format
    # 
    # _@param_ `time` — time of breadcrumb, should respond to `.to_i` defaults to `Time.now.utc`
    # 
    # _@see_ `Appsignal.add_breadcrumb`
    # 
    # _@see_ `https://docs.appsignal.com/ruby/instrumentation/breadcrumbs.html` — Breadcrumb reference
    sig do
      params(
        category: String,
        action: String,
        message: String,
        metadata: T::Hash[String, String],
        time: Time
      ).void
    end
    def add_breadcrumb(category, action, message = "", metadata = {}, time = Time.now.utc); end

    # Set an action name for the transaction.
    # 
    # An action name is used to identify the location of a certain sample;
    # error and performance issues.
    # 
    # _@param_ `action` — the action name to set.
    # 
    # _@see_ `Appsignal::Helpers::Instrumentation#set_action`
    sig { params(action: String).void }
    def set_action(action); end

    # Set the namespace for this transaction.
    # 
    # Useful to split up parts of an application into certain namespaces. For
    # example: http requests, background jobs and administration panel
    # controllers.
    # 
    # Note: The "http_request" namespace gets transformed on AppSignal.com to
    # "Web" and "background_job" gets transformed to "Background".
    # 
    # _@param_ `namespace` — namespace name to use for this transaction.
    # 
    # ```ruby
    # transaction.set_namespace("background")
    # ```
    # 
    # _@see_ `Appsignal::Helpers::Instrumentation#set_namespace`
    # 
    # _@see_ `https://docs.appsignal.com/guides/namespaces.html` — Grouping with namespaces guide
    sig { params(namespace: String).void }
    def set_namespace(namespace); end

    # Set queue start time for transaction.
    # 
    # _@param_ `start` — Queue start time in milliseconds.
    sig { params(start: Integer).void }
    def set_queue_start(start); end
  end

  # Custom markers are used on AppSignal.com to indicate events in an
  # application, to give additional context on graph timelines.
  # 
  # This helper class will send a request to the AppSignal public endpoint to
  # create a Custom marker for the application on AppSignal.com.
  # 
  # @see https://docs.appsignal.com/api/public-endpoint/custom-markers.html
  #   Public Endpoint API markers endpoint documentation
  # @see https://docs.appsignal.com/appsignal/terminology.html#markers
  #   Terminology: Markers
  class CustomMarker
    # _@param_ `icon` — icon to use for the marker, like an emoji.
    # 
    # _@param_ `message` — name of the user that is creating the marker.
    # 
    # _@param_ `created_at` — A Ruby time object or a valid ISO8601 timestamp.
    sig { params(icon: T.nilable(String), message: T.nilable(String), created_at: T.nilable(T.any(Time, String))).returns(T::Boolean) }
    def self.report(icon: nil, message: nil, created_at: nil); end
  end

  # Keeps track of formatters for types event that we can use to get
  # the title and body of an event. Formatters should inherit from this class
  # and implement a format(payload) method which returns an array with the title
  # and body.
  # 
  # When implementing a formatter remember that it cannot keep separate state per
  # event, the same object will be called intermittently in a threaded environment.
  # So only keep global configuration as state and pass the payload around as an
  # argument if you need to use helper methods.
  class EventFormatter
    DEFAULT = T.let(0, T.untyped)
    SQL_BODY_FORMAT = T.let(1, T.untyped)

    # Registers an event formatter for a specific event name.
    # 
    # _@param_ `name` — The name of the event to register the formatter for.
    # 
    # _@param_ `formatter` — The formatter class that implements the `format(payload)` method.
    # 
    # Register a custom formatter
    # ```ruby
    # class CustomFormatter < Appsignal::EventFormatter
    #   def format(payload)
    #     ["Custom event", payload[:body]]
    #   end
    # end
    # 
    # Appsignal::EventFormatter.register("my.event", CustomFormatter)
    # ```
    # 
    # _@see_ `#unregister`
    # 
    # _@see_ `#registered?`
    sig { params(name: T.any(String, Symbol), formatter: T.nilable(Class)).void }
    def self.register(name, formatter = nil); end

    # Unregisters an event formatter for a specific event name.
    # 
    # _@param_ `name` — The name of the event to unregister the formatter for.
    # 
    # _@param_ `formatter` — The formatter class to unregister. Defaults to `self`.
    # 
    # Unregister a custom formatter
    # ```ruby
    # Appsignal::EventFormatter.unregister("my.event", CustomFormatter)
    # ```
    # 
    # _@see_ `#register`
    # 
    # _@see_ `#registered?`
    sig { params(name: T.any(String, Symbol), formatter: Class).void }
    def self.unregister(name, formatter = self); end

    # Checks if an event formatter is registered for a specific event name.
    # 
    # _@param_ `name` — The name of the event to check.
    # 
    # _@param_ `klass` — The specific formatter class to check for. Optional.
    # 
    # _@return_ — true if a formatter is registered, false otherwise.
    # 
    # _@see_ `#register`
    # 
    # _@see_ `#unregister`
    sig { params(name: T.any(String, Symbol), klass: T.nilable(Class)).returns(T::Boolean) }
    def self.registered?(name, klass = nil); end
  end

  module Helpers
    module Metrics
      # Report a gauge metric.
      # 
      # _@param_ `name` — The name of the metric.
      # 
      # _@param_ `value` — The value of the metric.
      # 
      # _@param_ `tags` — The tags for the metric. The Hash keys can be either a String or a Symbol. The tag values can be a String, Symbol, Integer, Float, TrueClass or FalseClass.
      # 
      # _@see_ `https://docs.appsignal.com/metrics/custom.html` — Metrics documentation
      sig { params(name: T.any(String, Symbol), value: T.any(Integer, Float), tags: T::Hash[String, Object]).void }
      def set_gauge(name, value, tags = {}); end

      # Report a counter metric.
      # 
      # _@param_ `name` — The name of the metric.
      # 
      # _@param_ `value` — The value of the metric.
      # 
      # _@param_ `tags` — The tags for the metric. The Hash keys can be either a String or a Symbol. The tag values can be a String, Symbol, Integer, Float, TrueClass or FalseClass.
      # 
      # _@see_ `https://docs.appsignal.com/metrics/custom.html` — Metrics documentation
      sig { params(name: T.any(String, Symbol), value: T.any(Integer, Float), tags: T::Hash[String, Object]).void }
      def increment_counter(name, value = 1.0, tags = {}); end

      # Report a distribution metric.
      # 
      # _@param_ `name` — The name of the metric.
      # 
      # _@param_ `value` — The value of the metric.
      # 
      # _@param_ `tags` — The tags for the metric. The Hash keys can be either a String or a Symbol. The tag values can be a String, Symbol, Integer, Float, TrueClass or FalseClass.
      # 
      # _@see_ `https://docs.appsignal.com/metrics/custom.html` — Metrics documentation
      sig { params(name: T.any(String, Symbol), value: T.any(Integer, Float), tags: T::Hash[String, Object]).void }
      def add_distribution_value(name, value, tags = {}); end
    end

    module Instrumentation
      # Monitor a block of code with AppSignal.
      # 
      # This is a helper to create an AppSignal transaction, track any errors
      # that may occur and complete the transaction.
      # 
      # This helper is recommended to be used in Ruby scripts and parts of an
      # app not already instrumented by AppSignal's automatic instrumentations.
      # 
      # Use this helper in combination with our {.instrument} helper to track
      # instrumentation events.
      # 
      # If AppSignal is not active ({Appsignal.active?}) it will still execute
      # the block, but not create a transaction for it.
      # 
      # _@param_ `namespace` — The namespace to set on the new transaction. Defaults to the 'web' namespace. This will not update the active transaction's namespace if {.monitor} is called when another transaction is already active.
      # 
      # _@param_ `action` — The action name for the transaction. The action name is required to be set for the transaction to be reported. The argument can be set to `nil` or `:set_later` if the action is set within the block with {#set_action}. This will not update the active transaction's action if {.monitor} is called when another transaction is already active.
      # 
      # _@return_ — The value of the given block is returned.
      # Returns `nil` if there already is a transaction active and no block
      # was given.
      # 
      # Instrument a block of code
      # ```ruby
      # Appsignal.monitor(
      #   :namespace => "my_namespace",
      #   :action => "MyClass#my_method"
      # ) do
      #   # Some code
      # end
      # ```
      # 
      # Instrument a block of code using the default namespace
      # ```ruby
      # Appsignal.monitor(
      #   :action => "MyClass#my_method"
      # ) do
      #   # Some code
      # end
      # ```
      # 
      # Instrument a block of code with an instrumentation event
      # ```ruby
      # Appsignal.monitor(
      #   :namespace => "my_namespace",
      #   :action => "MyClass#my_method"
      # ) do
      #   Appsignal.instrument("some_event.some_group") do
      #     # Some code
      #   end
      # end
      # ```
      # 
      # Set the action name in the monitor block
      # ```ruby
      # Appsignal.monitor(
      #   :action => nil
      # ) do
      #   # Some code
      # 
      #   Appsignal.set_action("GET /resource/:id")
      # end
      # ```
      # 
      # Set the action name in the monitor block
      # ```ruby
      # Appsignal.monitor(
      #   :action => :set_later # Explicit placeholder
      # ) do
      #   # Some code
      # 
      #   Appsignal.set_action("GET /resource/:id")
      # end
      # ```
      # 
      # Set custom metadata on the transaction
      # ```ruby
      # Appsignal.monitor(
      #   :namespace => "my_namespace",
      #   :action => "MyClass#my_method"
      # ) do
      #   # Some code
      # 
      #   Appsignal.add_tags(:tag1 => "value1", :tag2 => "value2")
      #   Appsignal.add_params(:param1 => "value1", :param2 => "value2")
      # end
      # ```
      # 
      # Call monitor within monitor will do nothing
      # ```ruby
      # Appsignal.monitor(
      #   :namespace => "my_namespace",
      #   :action => "MyClass#my_method"
      # ) do
      #   # This will _not_ update the namespace and action name
      #   Appsignal.monitor(
      #     :namespace => "my_other_namespace",
      #     :action => "MyOtherClass#my_other_method"
      #   ) do
      #     # Some code
      # 
      #     # The reported namespace will be "my_namespace"
      #     # The reported action will be "MyClass#my_method"
      #   end
      # end
      # ```
      # 
      # _@see_ `https://docs.appsignal.com/ruby/instrumentation/background-jobs.html` — Monitor guide
      sig { params(action: T.any(String, Symbol, NilClass), namespace: T.nilable(T.any(String, Symbol)), blk: T.proc.returns(Object)).returns(T.nilable(Object)) }
      def monitor(action:, namespace: nil, &blk); end

      # Instrument a block of code and stop AppSignal.
      # 
      # Useful for cases such as one-off scripts where there is no long running
      # process active and the data needs to be sent after the process exists.
      # 
      # Acts the same way as {.monitor}. See that method for more
      # documentation.
      # 
      # _@param_ `namespace` — The namespace to set on the new transaction. Defaults to the 'web' namespace. This will not update the active transaction's namespace if {.monitor} is called when another transaction is already active.
      # 
      # _@param_ `action` — The action name for the transaction. The action name is required to be set for the transaction to be reported. The argument can be set to `nil` or `:set_later` if the action is set within the block with {#set_action}. This will not update the active transaction's action if {.monitor} is called when another transaction is already active.
      # 
      # _@return_ — The value of the given block is returned.
      # 
      # _@see_ `monitor`
      sig { params(action: T.any(String, Symbol, NilClass), namespace: T.nilable(T.any(String, Symbol)), block: T.proc.returns(Object)).returns(T.nilable(Object)) }
      def monitor_and_stop(action:, namespace: nil, &block); end

      # Send an error to AppSignal regardless of the context.
      # 
      # **We recommend using the {#report_error} helper instead.**
      # 
      # Records and send the exception to AppSignal.
      # 
      # This instrumentation helper does not require a transaction to be
      # active, it starts a new transaction by itself.
      # 
      # Use {.set_error} if your want to add an exception to the current
      # transaction.
      # 
      # **Note**: Does not do anything if AppSignal is not active or when the
      # "error" is not a class extended from Ruby's Exception class.
      # 
      # _@param_ `error` — The error to send to AppSignal.
      # 
      # Send an exception
      # ```ruby
      # begin
      #   raise "oh no!"
      # rescue => e
      #   Appsignal.send_error(e)
      # end
      # ```
      # 
      # Add more metadata to transaction
      # ```ruby
      # Appsignal.send_error(e) do
      #   Appsignal.set_namespace("my_namespace")
      #   Appsignal.set_action("my_action_name")
      #   Appsignal.add_params(:search_query => params[:search_query])
      #   Appsignal.add_tags(:key => "value")
      # end
      # ```
      # 
      # _@see_ `https://docs.appsignal.com/ruby/instrumentation/exception-handling.html` — Exception handling guide
      sig { params(error: Exception, block: T.proc.params(transaction: Transaction).void).void }
      def send_error(error, &block); end

      # Set an error on the current transaction.
      # 
      # **We recommend using the {#report_error} helper instead.**
      # 
      # **Note**: Does not do anything if AppSignal is not active, no
      # transaction is currently active or when the "error" is not a class
      # extended from Ruby's Exception class.
      # 
      # _@param_ `exception` — The error to add to the current transaction.
      # 
      # Manual instrumentation of set_error.
      # ```ruby
      # # Manually starting AppSignal here
      # # Manually starting a transaction here.
      # begin
      #   raise "oh no!"
      # rescue => e
      #   Appsignal.set_error(e)
      # end
      # # Manually completing the transaction here.
      # # Manually stopping AppSignal here
      # ```
      # 
      # In a Rails application
      # ```ruby
      # class SomeController < ApplicationController
      #   # The AppSignal transaction is created by our integration for you.
      #   def create
      #     # Do something that breaks
      #   rescue => e
      #     Appsignal.set_error(e)
      #   end
      # end
      # ```
      # 
      # Add more metadata to transaction
      # ```ruby
      # Appsignal.set_error(e) do
      #   Appsignal.set_namespace("my_namespace")
      #   Appsignal.set_action("my_action_name")
      #   Appsignal.add_params(:search_query => params[:search_query])
      #   Appsignal.add_tags(:key => "value")
      # end
      # ```
      # 
      # _@see_ `https://docs.appsignal.com/ruby/instrumentation/exception-handling.html` — Exception handling guide
      sig { params(exception: Exception, blk: T.proc.params(transaction: Transaction).void).void }
      def set_error(exception, &blk); end

      # Report an error to AppSignal.
      # 
      # If a transaction is currently active, it will report the error on the
      # current transaction. If no transaction is active, it will report the
      # error on a new transaction.
      # 
      # If a transaction is active and the transaction already has an error
      # reported on it, it will report multiple errors, up to a maximum of 10
      # errors.
      # 
      # If a block is given to this method, the metadata set in this block will
      # only be applied to the transaction created for the given error. The
      # block will be called when the transaction is completed, which can be
      # much later than when {#report_error} is called.
      # 
      # **Note**: If AppSignal is not active, no error is reported.
      # 
      # **Note**: If the given exception argument is not an Exception subclass,
      # it will not be reported.
      # 
      # _@param_ `exception` — The error to add to the current transaction.
      # 
      # ```ruby
      # class SomeController < ApplicationController
      #   def create
      #     # Do something that breaks
      #   rescue => error
      #     Appsignal.report_error(error)
      #   end
      # end
      # ```
      # 
      # Add more metadata to transaction
      # ```ruby
      # Appsignal.report_error(error) do
      #   Appsignal.set_namespace("my_namespace")
      #   Appsignal.set_action("my_action_name")
      #   Appsignal.add_params(:search_query => params[:search_query])
      #   Appsignal.add_tags(:key => "value")
      # end
      # ```
      # 
      # _@see_ `https://docs.appsignal.com/ruby/instrumentation/exception-handling.html` — Exception handling guide
      sig { params(exception: Exception, block: T.proc.params(transaction: Transaction).void).void }
      def report_error(exception, &block); end

      # Set a custom action name for the current transaction.
      # 
      # When using an integration such as the Rails or Sinatra AppSignal will
      # try to find the action name from the controller or endpoint for you.
      # 
      # If you want to customize the action name as it appears on AppSignal.com
      # you can use this method. This overrides the action name AppSignal
      # generates in an integration.
      # 
      # _@param_ `action`
      # 
      # in a Rails controller
      # ```ruby
      # class SomeController < ApplicationController
      #   before_action :set_appsignal_action
      # 
      #   def set_appsignal_action
      #     Appsignal.set_action("DynamicController#dynamic_method")
      #   end
      # end
      # ```
      sig { params(action: String).void }
      def set_action(action); end

      # Set a custom namespace for the current transaction.
      # 
      # When using an integration such as Rails or Sidekiq AppSignal will try
      # to find a appropriate namespace for the transaction.
      # 
      # A Rails controller will be automatically put in the "http_request"
      # namespace, while a Sidekiq background job is put in the
      # "background_job" namespace.
      # 
      # Note: The "http_request" namespace gets transformed on AppSignal.com to
      # "Web" and "background_job" gets transformed to "Background".
      # 
      # If you want to customize the namespace in which transactions appear you
      # can use this method. This overrides the namespace AppSignal uses by
      # default.
      # 
      # A common request we've seen is to split the administration panel from
      # the main application.
      # 
      # _@param_ `namespace`
      # 
      # create a custom admin namespace
      # ```ruby
      # class AdminController < ApplicationController
      #   before_action :set_appsignal_namespace
      # 
      #   def set_appsignal_namespace
      #     Appsignal.set_namespace("admin")
      #   end
      # end
      # ```
      # 
      # _@see_ `https://docs.appsignal.com/guides/namespaces.html` — Grouping with namespaces guide
      sig { params(namespace: String).void }
      def set_namespace(namespace); end

      # Add custom data to the current transaction.
      # 
      # Add extra information about the request or background that cannot be
      # expressed in tags, like nested data structures.
      # 
      # If the root data type changes between calls of this method, the last
      # method call is stored.
      # 
      # _@param_ `data` — Custom data to add to the transaction.
      # 
      # Add Hash data
      # ```ruby
      # Appsignal.add_custom_data(:user => { :locale => "en" })
      # ```
      # 
      # Merges Hash data
      # ```ruby
      # Appsignal.add_custom_data(:abc => "def")
      # Appsignal.add_custom_data(:xyz => "...")
      # # The custom data is: { :abc => "def", :xyz => "..." }
      # ```
      # 
      # Add Array data
      # ```ruby
      # Appsignal.add_custom_data([
      #   "array with data",
      #   "other value",
      #   :options => { :verbose => true }
      # ])
      # ```
      # 
      # Merges Array data
      # ```ruby
      # Appsignal.add_custom_data([1, 2, 3])
      # Appsignal.add_custom_data([4, 5, 6])
      # # The custom data is: [1, 2, 3, 4, 5, 6]
      # ```
      # 
      # Mixing of root data types is not supported
      # ```ruby
      # Appsignal.add_custom_data(:abc => "def")
      # Appsignal.add_custom_data([1, 2, 3])
      # # The custom data is: [1, 2, 3]
      # ```
      # 
      # _@see_ `https://docs.appsignal.com/guides/custom-data/sample-data.html` — Sample data guide
      sig { params(data: T.any(T::Hash[Object, Object], T::Array[Object])).void }
      def add_custom_data(data); end

      # Add tags to the current transaction.
      # 
      # Tags are extra bits of information that are added to transaction and
      # appear on sample details pages on AppSignal.com.
      # 
      # When this method is called multiple times, it will merge the tags.
      # 
      # _@param_ `tags` — Collection of tags to add to the transaction.
      # 
      # ```ruby
      # Appsignal.add_tags(:locale => "en", :user_id => 1)
      # Appsignal.add_tags("locale" => "en")
      # Appsignal.add_tags("user_id" => 1)
      # ```
      # 
      # Nested hashes are not supported
      # ```ruby
      # # Bad
      # Appsignal.add_tags(:user => { :locale => "en" })
      # ```
      # 
      # in a Rails controller
      # ```ruby
      # class SomeController < ApplicationController
      #   before_action :add_appsignal_tags
      # 
      #   def add_appsignal_tags
      #     Appsignal.add_tags(:locale => I18n.locale)
      #   end
      # end
      # ```
      # 
      # _@see_ `https://docs.appsignal.com/ruby/instrumentation/tagging.html` — Tagging guide
      sig { params(tags: T::Hash[Object, Object]).void }
      def add_tags(tags = {}); end

      # Add parameters to the current transaction.
      # 
      # Parameters are automatically added by most of our integrations. It
      # should not be necessary to call this method unless you want to report
      # different parameters.
      # 
      # This method accepts both Hash and Array parameter types:
      # - Hash parameters will be merged when called multiple times
      # - Array parameters will be concatenated when called multiple times
      # - Mixing Hash and Array types will use the latest type (and log a warning)
      # 
      # To filter parameters, see our parameter filtering guide.
      # 
      # When both the `params` argument and a block is given to this method,
      # the block is leading and the argument will _not_ be used.
      # 
      # _@param_ `params` — The parameters to add to the transaction.
      # 
      # Add Hash parameters
      # ```ruby
      # Appsignal.add_params("param1" => "value1")
      # # The parameters include: { "param1" => "value1" }
      # ```
      # 
      # Add Array parameters
      # ```ruby
      # Appsignal.add_params(["item1", "item2"])
      # # The parameters include: ["item1", "item2"]
      # ```
      # 
      # Calling `add_params` multiple times with Hashes merges values
      # ```ruby
      # Appsignal.add_params("param1" => "value1")
      # Appsignal.add_params("param2" => "value2")
      # # The parameters include:
      # # { "param1" => "value1", "param2" => "value2" }
      # ```
      # 
      # Calling `add_params` multiple times with Arrays concatenates values
      # ```ruby
      # Appsignal.add_params(["item1"])
      # Appsignal.add_params(["item2"])
      # # The parameters include: ["item1", "item2"]
      # ```
      # 
      # _@see_ `https://docs.appsignal.com/guides/custom-data/sample-data.html` — Sample data guide
      # 
      # _@see_ `https://docs.appsignal.com/guides/filter-data/filter-parameters.html` — Parameter filtering guide
      sig { params(params: T.nilable(T.any(T::Hash[String, Object], T::Array[Object])), block: T.proc.returns(T.any(T::Hash[String, Object], T::Array[Object]))).void }
      def add_params(params = nil, &block); end

      # Mark the parameters sample data to be set as an empty value.
      # 
      # Use this helper to unset request parameters / background job arguments
      # and not report any for this transaction.
      # 
      # If parameters would normally be added by AppSignal instrumentations of
      # libraries, these parameters will not be added to the Transaction.
      # 
      # Calling {#add_params} after this helper will add new parameters to the
      # transaction.
      # 
      # _@see_ `Transaction#set_empty_params!`
      # 
      # _@see_ `Transaction#set_params_if_nil`
      sig { void }
      def set_empty_params!; end

      # Add session data to the current transaction.
      # 
      # Session data is automatically added by most of our integrations. It
      # should not be necessary to call this method unless you want to report
      # different session data.
      # 
      # To filter session data, see our session data filtering guide.
      # 
      # When both the `session_data` argument and a block is given to this
      # method, the bock is leading and the argument will _not_ be used.
      # 
      # _@param_ `session_data` — The session data to add to the transaction.
      # 
      # Add session data
      # ```ruby
      # Appsignal.add_session_data("session" => "data")
      # # The session data will include:
      # # { "session" => "data" }
      # ```
      # 
      # Calling `add_session_data` multiple times merge the values
      # ```ruby
      # Appsignal.add_session_data("session" => "data")
      # Appsignal.add_session_data("other" => "value")
      # # The session data will include:
      # # { "session" => "data", "other" => "value" }
      # ```
      # 
      # _@see_ `https://docs.appsignal.com/guides/custom-data/sample-data.html` — Sample data guide
      # 
      # _@see_ `https://docs.appsignal.com/guides/filter-data/filter-session-data.html` — Session data filtering guide
      sig { params(session_data: T.nilable(T::Hash[String, Object]), block: T.proc.returns(T::Hash[String, Object])).void }
      def add_session_data(session_data = nil, &block); end

      # Add request headers to the current transaction.
      # 
      # Request headers are automatically added by most of our integrations. It
      # should not be necessary to call this method unless you want to also
      # report different request headers.
      # 
      # To filter request headers, see our request header filtering guide.
      # 
      # When both the `request_headers` argument and a block is given to this
      # method, the block is leading and the argument will _not_ be used.
      # 
      # _@param_ `headers` — The request headers to add to the transaction.
      # 
      # Add request headers
      # ```ruby
      # Appsignal.add_headers("PATH_INFO" => "/some-path")
      # # The request headers will include:
      # # { "PATH_INFO" => "/some-path" }
      # ```
      # 
      # Calling `add_headers` multiple times merge the values
      # ```ruby
      # Appsignal.add_headers("PATH_INFO" => "/some-path")
      # Appsignal.add_headers("HTTP_USER_AGENT" => "Firefox")
      # # The request headers will include:
      # # { "PATH_INFO" => "/some-path", "HTTP_USER_AGENT" => "Firefox" }
      # ```
      # 
      # _@see_ `https://docs.appsignal.com/guides/custom-data/sample-data.html` — Sample data guide
      # 
      # _@see_ `https://docs.appsignal.com/guides/filter-data/filter-headers.html` — Request headers filtering guide
      sig { params(headers: T.nilable(T::Hash[String, Object]), block: T.proc.returns(T::Hash[String, Object])).void }
      def add_headers(headers = nil, &block); end

      # Add breadcrumbs to the transaction.
      # 
      # Breadcrumbs can be used to trace what path a user has taken
      # before encountering an error.
      # 
      # Only the last 20 added breadcrumbs will be saved.
      # 
      # _@param_ `category` — category of breadcrumb e.g. "UI", "Network", "Navigation", "Console".
      # 
      # _@param_ `action` — name of breadcrumb e.g "The user clicked a button", "HTTP 500 from http://blablabla.com"
      # 
      # _@param_ `message` — optional message in string format
      # 
      # _@param_ `metadata` — key/value metadata in <string, string> format
      # 
      # _@param_ `time` — time of breadcrumb, should respond to `.to_i` defaults to `Time.now.utc`
      # 
      # ```ruby
      # Appsignal.add_breadcrumb(
      #   "Navigation",
      #   "http://blablabla.com",
      #   "",
      #   { :response => 200 },
      #   Time.now.utc
      # )
      # Appsignal.add_breadcrumb(
      #   "Network",
      #   "[GET] http://blablabla.com",
      #   "",
      #   { :response => 500 }
      # )
      # Appsignal.add_breadcrumb(
      #   "UI",
      #   "closed modal(change_password)",
      #   "User closed modal without actions"
      # )
      # ```
      # 
      # _@see_ `https://docs.appsignal.com/ruby/instrumentation/breadcrumbs.html` — Breadcrumb reference
      sig do
        params(
          category: String,
          action: String,
          message: String,
          metadata: T::Hash[String, String],
          time: Time
        ).void
      end
      def add_breadcrumb(category, action, message = "", metadata = {}, time = Time.now.utc); end

      # Instrument helper for AppSignal.
      # 
      # For more help, read our custom instrumentation guide, listed under "See
      # also".
      # 
      # _@param_ `name` — Name of the instrumented event. Read our event naming guide listed under "See also".
      # 
      # _@param_ `title` — Human readable name of the event.
      # 
      # _@param_ `body` — Value of importance for the event, such as the server against an API call is made.
      # 
      # _@param_ `body_format` — Enum for the type of event that is instrumented. Accepted values are {EventFormatter::DEFAULT} and {EventFormatter::SQL_BODY_FORMAT}, but we recommend you use {.instrument_sql} instead of {EventFormatter::SQL_BODY_FORMAT}.
      # 
      # _@return_ — Returns the block's return value.
      # 
      # Simple instrumentation
      # ```ruby
      # Appsignal.instrument("fetch.issue_fetcher") do
      #   # To be instrumented code
      # end
      # ```
      # 
      # Instrumentation with title and body
      # ```ruby
      # Appsignal.instrument(
      #   "fetch.issue_fetcher",
      #   "Fetching issue",
      #   "GitHub API"
      # ) do
      #   # To be instrumented code
      # end
      # ```
      # 
      # _@see_ `.instrument_sql`
      # 
      # _@see_ `https://docs.appsignal.com/ruby/instrumentation/instrumentation.html` — AppSignal custom instrumentation guide
      # 
      # _@see_ `https://docs.appsignal.com/api/event-names.html` — AppSignal event naming guide
      sig do
        params(
          name: String,
          title: T.nilable(String),
          body: T.nilable(String),
          body_format: Integer,
          block: T.untyped
        ).returns(Object)
      end
      def instrument(name, title = nil, body = nil, body_format = Appsignal::EventFormatter::DEFAULT, &block); end

      # Instrumentation helper for SQL queries.
      # 
      # This helper filters out values from SQL queries so you don't have to.
      # 
      # _@param_ `name` — Name of the instrumented event. Read our event naming guide listed under "See also".
      # 
      # _@param_ `title` — Human readable name of the event.
      # 
      # _@param_ `body` — SQL query that's being executed.
      # 
      # _@return_ — Returns the block's return value.
      # 
      # SQL query instrumentation
      # ```ruby
      # body = "SELECT * FROM ..."
      # Appsignal.instrument_sql("perform.query", nil, body) do
      #   # To be instrumented code
      # end
      # ```
      # 
      # SQL query instrumentation
      # ```ruby
      # body = "WHERE email = 'foo@..'"
      # Appsignal.instrument_sql("perform.query", nil, body) do
      #   # query value will replace 'foo..' with a question mark `?`.
      # end
      # ```
      # 
      # _@see_ `.instrument`
      # 
      # _@see_ `https://docs.appsignal.com/ruby/instrumentation/instrumentation.html` — AppSignal custom instrumentation guide
      # 
      # _@see_ `https://docs.appsignal.com/api/event-names.html` — AppSignal event naming guide
      sig do
        params(
          name: String,
          title: T.nilable(String),
          body: T.nilable(String),
          block: T.untyped
        ).returns(Object)
      end
      def instrument_sql(name, title = nil, body = nil, &block); end

      # Convenience method for ignoring instrumentation events in a block of
      # code.
      # 
      # - This helper ignores events, like those created
      #   `Appsignal.instrument`, within this block.
      #   This includes custom instrumentation and events recorded by AppSignal
      #   integrations for requests, database queries, view rendering, etc.
      # - The time spent in the block is still reported on the transaction.
      # - Errors and metrics are reported from within this block.
      # 
      # _@return_ — Returns the return value of the block.
      # Return nil if the block returns nil or no block is given.
      # 
      # ```ruby
      # Appsignal.instrument "my_event.my_group" do
      #   # Complex code here
      # end
      # Appsignal.ignore_instrumentation_events do
      #   Appsignal.instrument "my_ignored_event.my_ignored_group" do
      #     # Complex code here
      #   end
      # end
      # 
      # # Only the "my_event.my_group" instrumentation event is reported.
      # ```
      # 
      # _@see_ `https://docs.appsignal.com/ruby/instrumentation/ignore-instrumentation.html` — Ignore instrumentation guide
      sig { params(blk: T.proc.returns(Object)).returns(T.nilable(Object)) }
      def ignore_instrumentation_events(&blk); end
    end
  end

  class InternalError < StandardError
  end

  class NotStartedError < Appsignal::InternalError
    sig { returns(String) }
    def message; end
  end
end

# Extensions to Object for AppSignal method instrumentation.
# 
# @see https://docs.appsignal.com/ruby/instrumentation/method-instrumentation.html
#   Method instrumentation documentation.
class Object < BasicObject
  # Instruments a class method with AppSignal monitoring.
  # 
  # _@param_ `method_name` — The name of the class method to instrument.
  # 
  # _@param_ `options` — Options for instrumentation.
  # 
  # _@see_ `https://docs.appsignal.com/ruby/instrumentation/method-instrumentation.html` — Method instrumentation documentation.
  sig { params(method_name: Symbol, options: T::Hash[Symbol, String]).returns(Symbol) }
  def self.appsignal_instrument_class_method(method_name, options = {}); end

  # Instruments an instance method with AppSignal monitoring.
  # 
  # _@param_ `method_name` — The name of the instance method to instrument.
  # 
  # _@param_ `options` — Options for instrumentation.
  # 
  # _@see_ `https://docs.appsignal.com/ruby/instrumentation/method-instrumentation.html` — Method instrumentation documentation.
  sig { params(method_name: Symbol, options: T::Hash[Symbol, String]).returns(Symbol) }
  def self.appsignal_instrument_method(method_name, options = {}); end
end
