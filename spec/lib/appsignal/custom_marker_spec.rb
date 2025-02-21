describe Appsignal::CustomMarker do
  let(:config) { build_config }

  describe "#transmit" do
    # def stub_marker_request
    #   stub_api_request config, "markers", marker.marker_data
    # end

    def create_marker(
      icon: nil,
      message: nil,
      created_at: nil
    )
      described_class.report(
        :icon => icon,
        :message => message,
        :created_at => created_at
      )
    end

    context "without Appsignal.config" do
      it "logs a warning" do
        logs =
          capture_logs do
            expect(create_marker(
              :icon => "🎉",
              :message => "Migration completed",
              :created_at => Time.now
            )).to be(false)
          end
        expect(logs)
          .to contains_log(:warn, "Did not transmit custom marker: no AppSignal config loaded")
      end
    end

    context "with Appsignal.config" do
      before { configure }

      context "when request is valid" do
        it "sends request with all parameters and logs success" do
          time = "2025-02-21T11:03:48+01:00"
          stub_public_endpoint_markers_request(
            :marker_data => {
              "icon" => "🎉",
              "message" => "Migration completed",
              "created_at" => time
            }
          ).to_return(:status => 200)

          logs =
            capture_logs do
              expect(create_marker(
                :icon => "🎉",
                :message => "Migration completed",
                :created_at => time
              )).to be(true)
            end

          expect(logs).to contains_log(:info, "Transmitted custom marker")
          expect(logs).to_not contains_log(:error, "Failed to transmit custom marker")
        end

        it "sends request with time object as parameter and logs success" do
          time = Time.now.utc
          stub_public_endpoint_markers_request(
            :marker_data => {
              "icon" => "🎉",
              "message" => "Migration completed",
              "created_at" => time.iso8601
            }
          ).to_return(:status => 200)

          logs =
            capture_logs do
              expect(create_marker(
                :icon => "🎉",
                :message => "Migration completed",
                :created_at => time
              )).to be(true)
            end

          expect(logs).to contains_log(:info, "Transmitted custom marker")
          expect(logs).to_not contains_log(:error, "Failed to transmit custom marker")
        end

        it "sends request with some parameters and logs success" do
          stub_public_endpoint_markers_request(
            :marker_data => {
              "message" => "Migration completed"
            }
          ).to_return(:status => 200)

          logs =
            capture_logs do
              expect(create_marker(:message => "Migration completed")).to be(true)
            end

          expect(logs).to contains_log(:info, "Transmitted custom marker")
          expect(logs).to_not contains_log(:error, "Failed to transmit custom marker")
        end
      end

      context "when request failed" do
        it "logs error" do
          time = Time.now.utc
          stub_public_endpoint_markers_request(
            :marker_data => {
              "icon" => "🎉",
              "message" => "Migration completed",
              "created_at" => time.iso8601
            }
          ).to_return(:status => 500)

          logs =
            capture_logs do
              expect(create_marker(
                :icon => "🎉",
                :message => "Migration completed",
                :created_at => time
              )).to be(false)
            end

          expect(logs).to_not contains_log(:info, "Transmitted custom marker")
          expect(logs).to contains_log(:error, "Failed to transmit custom marker: 500 status code")
        end
      end

      context "when request raised an error" do
        it "logs error" do
          time = Time.now.utc
          stub_public_endpoint_markers_request(
            :marker_data => {
              "icon" => "🎉",
              "message" => "Migration completed",
              "created_at" => time.iso8601
            }
          ).to_raise(RuntimeError.new("uh oh"))

          logs =
            capture_logs do
              expect(create_marker(
                :icon => "🎉",
                :message => "Migration completed",
                :created_at => time
              )).to be(false)
            end

          expect(logs).to_not contains_log(:info, "Transmitted custom marker")
          expect(logs)
            .to contains_log(:error, "Failed to transmit custom marker: RuntimeError: uh oh")
        end
      end
    end
  end
end
