require_relative "../../ext/base"

describe "extension installer" do
  describe "#ca_file_path" do
    it "uses the CA certificate bundled with the gem" do
      expect(ca_file_path).to eq(CA_CERT_PATH)
    end

    it "uses the CA certificate configured with APPSIGNAL_CA_FILE_PATH" do
      ENV["APPSIGNAL_CA_FILE_PATH"] = "/path/to/ca.pem"

      expect(ca_file_path).to eq("/path/to/ca.pem")
    end

    it "uses the bundled CA certificate when the configured path is blank" do
      ENV["APPSIGNAL_CA_FILE_PATH"] = " "

      expect(ca_file_path).to eq(CA_CERT_PATH)
    end
  end
end
