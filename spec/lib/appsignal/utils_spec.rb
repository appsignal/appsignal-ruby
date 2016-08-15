# encoding: UTF-8

require 'spec_helper'

describe Appsignal::Utils do
  describe ".json_generate" do
    subject { Appsignal::Utils.json_generate(body) }

    context "with a valid body" do
      let(:body) do
        {
          'the' => 'payload',
          1 => true,
          nil => 'test',
          :foo => [1, 2, 'three'],
          'bar' => nil,
          'baz' => { 'foo' => 'bar' }
        }
      end

      it { should == %({"the":"payload","1":true,"":"test","foo":[1,2,"three"],"bar":null,"baz":{"foo":"bar"}}) }
    end

    context "with a body that contains strings with invalid utf-8 content" do
      let(:string_with_invalid_utf8) { [0x61, 0x61, 0x85].pack('c*') }
      let(:body) { {
        'field_one' => [0x61, 0x61].pack('c*'),
        :field_two => string_with_invalid_utf8,
        'field_three' => [
          'one', string_with_invalid_utf8
        ],
        'field_four' => {
          'one' => string_with_invalid_utf8
        }
      } }

      it { should == %({"field_one":"aa","field_two":"aa�","field_three":["one","aa�"],"field_four":{"one":"aa�"}}) }
    end
  end
end
