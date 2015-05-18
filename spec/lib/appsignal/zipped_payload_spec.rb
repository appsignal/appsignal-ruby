# encoding: UTF-8

require 'spec_helper'

describe Appsignal::ZippedPayload do
  describe "#initialize" do
    it "should initialize a new `Appsignal::ZippedPayload` and zip the body" do
      payload = Appsignal::ZippedPayload.new({'the' => 'payload'})

      expect( payload.body ).to eql(Zlib::Deflate.deflate(
        "{\"the\":\"payload\"}",
        Zlib::BEST_SPEED
      ))
    end
  end

  describe ".json_generate" do
    subject { Appsignal::ZippedPayload.send(:json_generate, body) }

    context "with a valid body" do
      let(:body) { {'the' => 'payload'} }

      it { should == "{\"the\":\"payload\"}" }
    end

    context "with a body that contains strings with invalid utf-8 content" do
      let(:string_with_invalid_utf8) { [0x61, 0x61, 0x85].pack('c*') }
      let(:body) { {
        'field_one' => [0x61, 0x61].pack('c*'),
        'field_two' => string_with_invalid_utf8,
        'field_three' => [
          'one', string_with_invalid_utf8
        ],
        'field_four' => {
          'one' => string_with_invalid_utf8
        }
      } }

      it { should == "{\"field_one\":\"aa\",\"field_two\":\"aa�\",\"field_three\":[\"one\",\"aa�\"],\"field_four\":{\"one\":\"aa�\"}}" }
    end
  end
end
