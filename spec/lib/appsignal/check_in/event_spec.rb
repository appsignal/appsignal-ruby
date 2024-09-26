describe Appsignal::CheckIn::Event do
  describe "#describe" do
    it "describes an empty list of check-ins" do
      expect(
        described_class.describe([])
      ).to eq("no check-in events")
    end

    it "describes a cron check-in by identifier, kind, and digest" do
      expect(
        described_class.describe([
          described_class.cron(
            :identifier => "cron-checkin-name",
            :digest => "some-digest",
            :kind => "some-kind"
          )
        ])
      ).to eq("cron check-in `cron-checkin-name` some-kind event (digest some-digest)")
    end

    it "describes a heartbeat check-in by identifier" do
      expect(
        described_class.describe([
          described_class.heartbeat(:identifier => "heartbeat-checkin-name")
        ])
      ).to eq("heartbeat check-in `heartbeat-checkin-name` event")
    end

    it "describes an unknown check-in event" do
      expect(
        described_class.describe([
          described_class.new(
            :check_in_type => "unknown-type",
            :identifier => "unknown-checkin-name"
          )
        ])
      ).to eq("unknown check-in event")
    end

    it "describes multiple check-ins by count" do
      expect(
        described_class.describe([
          described_class.heartbeat(:identifier => "heartbeat-checkin-name"),
          described_class.cron(
            :identifier => "cron-checkin-name",
            :digest => "digest",
            :kind => "start"
          )
        ])
      ).to eq("2 check-in events")
    end
  end

  describe "#redundant?" do
    it "returns false for different check-in types" do
      event = described_class.heartbeat(:identifier => "checkin-name")
      other = described_class.cron(
        :identifier => "checkin-name",
        :digest => "digest",
        :kind => "start"
      )

      expect(
        described_class.redundant?(event, other)
      ).to be(false)
    end

    it "returns false for different heartbeat identifiers" do
      event = described_class.heartbeat(:identifier => "checkin-name")
      other = described_class.heartbeat(:identifier => "other-checkin-name")

      expect(
        described_class.redundant?(event, other)
      ).to be(false)
    end

    it "returns true for the same heartbeat identifier" do
      event = described_class.heartbeat(:identifier => "checkin-name")
      other = described_class.heartbeat(:identifier => "checkin-name")

      expect(
        described_class.redundant?(event, other)
      ).to be(true)
    end

    it "returns false for different cron identifiers" do
      event = described_class.cron(
        :identifier => "checkin-name",
        :digest => "digest",
        :kind => "start"
      )
      other = described_class.cron(
        :identifier => "other-checkin-name",
        :digest => "digest",
        :kind => "start"
      )

      expect(
        described_class.redundant?(event, other)
      ).to be(false)
    end

    it "returns false for different cron digests" do
      event = described_class.cron(
        :identifier => "checkin-name",
        :digest => "digest",
        :kind => "start"
      )
      other = described_class.cron(
        :identifier => "checkin-name",
        :digest => "other-digest",
        :kind => "start"
      )

      expect(
        described_class.redundant?(event, other)
      ).to be(false)
    end

    it "returns false for different cron kinds" do
      event = described_class.cron(
        :identifier => "checkin-name",
        :digest => "digest",
        :kind => "start"
      )
      other = described_class.cron(
        :identifier => "checkin-name",
        :digest => "digest",
        :kind => "finish"
      )

      expect(
        described_class.redundant?(event, other)
      ).to be(false)
    end

    it "returns true for the same cron identifier, digest, and kind" do
      event = described_class.cron(
        :identifier => "checkin-name",
        :digest => "digest",
        :kind => "start"
      )
      other = described_class.cron(
        :identifier => "checkin-name",
        :digest => "digest",
        :kind => "start"
      )

      expect(
        described_class.redundant?(event, other)
      ).to be(true)
    end

    it "returns false for unknown check-in event kinds" do
      event = described_class.new(
        :check_in_type => "unknown",
        :identifier => "checkin-name"
      )
      other = described_class.new(
        :check_in_type => "unknown",
        :identifier => "checkin-name"
      )

      expect(
        described_class.redundant?(event, other)
      ).to be(false)
    end
  end
end
