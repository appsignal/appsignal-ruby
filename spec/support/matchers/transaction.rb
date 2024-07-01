def define_transaction_metadata_matcher_for(matcher_key, value_key = matcher_key)
  value_key = value_key.to_s

  RSpec::Matchers.define "have_#{matcher_key}" do |expected_value|
    match(:notify_expectation_failures => true) do |transaction|
      actual_value = transaction.to_h[value_key]
      if expected_value
        expect(actual_value).to eq(expected_value)
      else
        expect(actual_value).to_not be_nil
      end
    end

    match_when_negated(:notify_expectation_failures => true) do |transaction|
      actual_value = transaction.to_h[value_key]
      if expected_value
        expect(actual_value).to_not eq(expected_value)
      else
        expect(actual_value).to be_nil
      end
    end
  end
end

define_transaction_metadata_matcher_for(:id)
define_transaction_metadata_matcher_for(:namespace)
define_transaction_metadata_matcher_for(:action)

def define_transaction_sample_matcher_for(matcher_key, value_key = matcher_key)
  value_key = value_key.to_s

  RSpec::Matchers.define "include_#{matcher_key}" do |expected_value|
    match(:notify_expectation_failures => true) do |transaction|
      sample_data = transaction.to_h.dig("sample_data", value_key) || {}

      if expected_value
        expected_value = hash_including(expected_value) if expected_value.is_a?(Hash)
        expect(sample_data).to match(expected_value)
      else
        expect(sample_data).to be_present
      end
    end

    match_when_negated(:notify_expectation_failures => true) do |transaction|
      sample_data = transaction.to_h.dig("sample_data", value_key) || {}

      if expected_value
        expect(sample_data).to_not include(expected_value)
      else
        expect(sample_data).to be_empty
      end
    end
  end
end

define_transaction_sample_matcher_for(:sample_metadata, :metadata)
define_transaction_sample_matcher_for(:params)
define_transaction_sample_matcher_for(:environment)
define_transaction_sample_matcher_for(:session_data)
define_transaction_sample_matcher_for(:tags)
define_transaction_sample_matcher_for(:custom_data)

RSpec::Matchers.define :be_completed do
  match(:notify_expectation_failures => true) do |transaction|
    values_match? transaction.ext._completed?, true
  end
end

RSpec::Matchers.define :have_error do |error_class, error_message|
  match(:notify_expectation_failures => true) do |transaction|
    transaction_error = transaction.to_h["error"]
    if error_class && error_message
      expect(transaction_error).to include(
        "name" => error_class,
        "message" => error_message,
        "backtrace" => kind_of(String)
      )
    else
      expect(transaction_error).to be_any
    end
  end

  match_when_negated(:notify_expectation_failures => true) do |transaction|
    transaction_error = transaction.to_h["error"]
    if error_class && error_message
      expect(transaction_error).to_not include(
        "name" => error_class,
        "message" => error_message,
        "backtrace" => kind_of(String)
      )
    else
      expect(transaction_error).to be_nil
    end
  end
end

RSpec::Matchers.define :include_event do |event|
  match(:notify_expectation_failures => true) do |transaction|
    events = transaction.to_h["events"]
    if event
      expect(events).to include(format_event(event))
    else
      expect(events).to be_any
    end
  end

  match_when_negated(:notify_expectation_failures => true) do |transaction|
    events = transaction.to_h["events"]
    if event
      expect(events).to_not include(format_event(event))
    else
      expect(events).to be_empty
    end
  end

  def format_event(event)
    hash_including({
      "body" => "",
      "body_format" => Appsignal::EventFormatter::DEFAULT,
      "count" => 1,
      "name" => kind_of(String),
      "title" => ""
    }.merge(event.transform_keys(&:to_s)))
  end
end
RSpec::Matchers.alias_matcher :include_events, :include_event

RSpec::Matchers.define :include_metadata do |metadata|
  match(:notify_expectation_failures => true) do |transaction|
    actual_metadata = transaction.to_h["metadata"]
    if metadata
      expect(actual_metadata).to include(metadata)
    else
      expect(actual_metadata).to be_any
    end
  end

  match_when_negated(:notify_expectation_failures => true) do |transaction|
    actual_metadata = transaction.to_h["metadata"]
    if metadata
      expect(actual_metadata).to_not include(metadata)
    else
      expect(actual_metadata).to be_empty
    end
  end
end

RSpec::Matchers.define :include_breadcrumb do |action, category, message, metadata, time|
  match(:notify_expectation_failures => true) do |transaction|
    breadcrumbs = transaction.to_h.dig("sample_data", "breadcrumbs")
    if action
      breadcrumb = format_breadcrumb(action, category, message, metadata, time)
      expect(breadcrumbs).to include(breadcrumb)
    else
      expect(transaction.to_h.dig("sample_data", "breadcrumbs")).to be_any
    end
  end

  match_when_negated(:notify_expectation_failures => true) do |transaction|
    breadcrumbs = transaction.to_h.dig("sample_data", "breadcrumbs")
    if action
      breadcrumb = format_breadcrumb(action, category, message, metadata, time)
      expect(breadcrumbs).to_not include(breadcrumb)
    else
      expect(breadcrumbs).to_not be_any
    end
  end

  def format_breadcrumb(action, category, message, metadata, time)
    {
      "action" => action,
      "category" => category,
      "message" => message,
      "metadata" => metadata,
      "time" => time
    }
  end
end
RSpec::Matchers.alias_matcher :include_breadcrumbs, :include_breadcrumb

RSpec::Matchers.define :have_queue_start do |queue_start_time|
  match(:notify_expectation_failures => true) do |transaction|
    expect(transaction.ext.queue_start).to eq(queue_start_time)
  end
end
