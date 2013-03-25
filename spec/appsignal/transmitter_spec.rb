require 'spec_helper'

describe Appsignal::Transmitter do
  let(:_80beans_) { 'http://www.80beans.com' }
  let(:action) { 'action' }
  let(:klass) { Appsignal::Transmitter }
  let(:instance) { klass.new(_80beans_, action, :the_api_key) }
  subject { instance }

  describe "#uri" do
    it "returns the uri" do
      Socket.stub(:gethostname => 'app1.local')
      subject.uri.should == URI(
        "http://www.80beans.com/action?api_key=the_api_key&"\
        "hostname=app1.local&gem_version=#{Appsignal::VERSION}"
      )
    end
  end

  describe "#transmit" do
    let(:response) { mock(:response, :code => '200') }
    let(:http_client) { mock(:request, :request => response) }
    before { instance.stub(:http_client => http_client) }

    subject { instance.transmit(:shipit => :payload) }

    it { should == '200' }
  end

  describe "#http_post" do
    it "calls Net::HTTP.post_form with the correct params" do
      post = mock(:post)
      post.should_receive(:[]=).
        with('Content-Type', 'application/json; charset=UTF-8')
      post.should_receive(:body=).with("{\"the\":\"payload\"}")
      Socket.stub(:gethostname => 'app1.local')

      Net::HTTP::Post.should_receive(:new).with(
        "/action?api_key=the_api_key&hostname=app1.local&"\
        "gem_version=#{Appsignal::VERSION}"
      ).and_return(post)
      instance.send(:http_post, :the => :payload)
    end
  end

  describe "ca_file_path" do
    subject { instance.send(:ca_file_path) }

    it { should include('resources/cacert.pem') }
    it("should exist") { File.exists?(subject).should be_true }
  end

  describe "#http_client" do
    subject { instance.send(:http_client) }

    context "with a http uri" do
      it { should be_instance_of(Net::HTTP) }

      its(:use_ssl?) { should be_false }
    end

    context "with a https uri" do
      let(:instance) { klass.new('https://www.80beans.com', action, :the_api_key) }

      its(:use_ssl?) { should be_true }
      its(:verify_mode) { should == OpenSSL::SSL::VERIFY_PEER }
      its(:ca_file) { include('resources/cacert.pem') }
    end
  end
end
