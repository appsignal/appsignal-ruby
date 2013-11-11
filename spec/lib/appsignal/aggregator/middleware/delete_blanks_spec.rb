require 'spec_helper'

describe Appsignal::Aggregator::Middleware::DeleteBlanks do
  let(:klass) { Appsignal::Aggregator::Middleware::DeleteBlanks }
  let(:delete_blanks) { klass.new }

  describe "#call" do
    let(:event) do
      notification_event(
        :name => 'something',
        :payload => create_payload(payload)
      )
    end
    let(:payload) do
      {
        :string => 'not empty',
        :array => ['something'],
        :hash => {'something' => 'something'},
        :empty_string => '',
        :empty_array => [],
        :empty_hash => {},
        :nil => nil
      }
    end
    subject { event.payload }
    before { delete_blanks.call(event) { } }

    it { should have_key(:string) }
    it { should have_key(:array) }
    it { should have_key(:hash) }

    it { should_not have_key(:empty_string) }
    it { should_not have_key(:empty_array) }
    it { should_not have_key(:empty_hash) }
    it { should_not have_key(:nil) }
  end
end
