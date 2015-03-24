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

end
