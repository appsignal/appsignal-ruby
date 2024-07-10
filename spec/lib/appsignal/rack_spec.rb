describe Appsignal::Rack::Utils do
  describe ".queue_start_from" do
    let(:header_time) { fixed_time - 0.4 }
    let(:header_time_value) { (header_time * factor).to_i }
    subject { described_class.queue_start_from(env) }

    shared_examples "HTTP queue start" do
      context "when env is nil" do
        let(:env) { nil }

        it { is_expected.to be_nil }
      end

      context "with no relevant header set" do
        let(:env) { {} }

        it { is_expected.to be_nil }
      end

      context "with the HTTP_X_REQUEST_START header set" do
        let(:env) { { "HTTP_X_REQUEST_START" => "t=#{header_time_value}" } }

        it { is_expected.to eq 1_389_783_599_600 }

        context "with unparsable content" do
          let(:env) { { "HTTP_X_REQUEST_START" => "something" } }

          it { is_expected.to be_nil }
        end

        context "with unparsable content at the end" do
          let(:env) { { "HTTP_X_REQUEST_START" => "t=#{header_time_value}aaaa" } }

          it { is_expected.to eq 1_389_783_599_600 }
        end

        context "with a really low number" do
          let(:env) { { "HTTP_X_REQUEST_START" => "t=100" } }

          it { is_expected.to be_nil }
        end

        context "with the alternate HTTP_X_QUEUE_START header set" do
          let(:env) { { "HTTP_X_QUEUE_START" => "t=#{header_time_value}" } }

          it { is_expected.to eq 1_389_783_599_600 }
        end
      end
    end

    context "time in milliseconds" do
      let(:factor) { 1_000 }

      it_should_behave_like "HTTP queue start"
    end

    context "time in microseconds" do
      let(:factor) { 1_000_000 }

      it_should_behave_like "HTTP queue start"
    end
  end
end
