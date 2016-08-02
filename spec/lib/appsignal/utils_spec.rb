# encoding: UTF-8

require 'spec_helper'

describe Appsignal::Utils do
  describe ".sanitize" do
    context "when params is a hash" do
      let(:params) { {'foo' => 'bar'} }

      it "should sanitize all hash values with a questionmark" do
        expect( Appsignal::Utils.sanitize(params) ).to eq('foo' => '?')
      end
    end

    context "when params is an array of hashes" do
      let(:params) { [{'foo' => 'bar'}] }

      it "should sanitize all hash values with a questionmark" do
        expect( Appsignal::Utils.sanitize(params) ).to eq([{'foo' => '?'}])
      end
    end

    context "when params is an array of strings" do
      let(:params) { ['foo', 'bar'] }

      it "should sanitize all hash values with a single questionmark" do
        expect( Appsignal::Utils.sanitize(params) ).to eq(['?'])
      end
    end

    context "when params is a mixed array" do
      let(:params) { [nil, 'foo', 'bar'] }

      it "should sanitize all hash values with a single questionmark" do
        expect( Appsignal::Utils.sanitize(params) ).to eq(['?'])
      end
    end

    context "when params is a string" do
      let(:params) { 'bar'}

      it "should sanitize all hash values with a questionmark" do
        expect( Appsignal::Utils.sanitize(params) ).to eq('?')
      end
    end
  end

  describe ".sanitize_key" do
    it "should not sanitize key when no key_sanitizer is given" do
      expect( Appsignal::Utils.sanitize_key('foo', nil) ).to eql('foo')
    end

    context "with mongodb sanitizer" do
      it "should not sanitize key when no dots are in the key" do
        expect( Appsignal::Utils.sanitize_key('foo', :mongodb) ).to eql('foo')
      end

      it "should sanitize key when dots are in the key" do
        expect( Appsignal::Utils.sanitize_key('foo.bar', :mongodb) ).to eql('foo.?')
      end

      it "should sanitize a symbol" do
        expect( Appsignal::Utils.sanitize_key(:ismaster, :mongodb) ).to eql('ismaster')
      end
    end
  end

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
