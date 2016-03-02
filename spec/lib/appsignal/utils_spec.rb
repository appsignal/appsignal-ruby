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

    context "when params is an array of strings " do
      let(:params) { ['foo', 'bar'] }

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
    end
  end
end
