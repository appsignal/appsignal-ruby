require File.expand_path("../../ext/base", __dir__)

describe "extension installer CA certificate path" do
  env_keys = %w[APPSIGNAL_CA_FILE_PATH SSL_CERT_FILE]

  around do |example|
    original_values = ENV.to_h.slice(*env_keys)
    env_keys.each { |key| ENV.delete(key) }
    example.run
  ensure
    env_keys.each { |key| ENV.delete(key) }
    original_values.each { |key, value| ENV[key] = value }
  end

  it "uses the packaged CA certificate path by default" do
    expect(ca_cert_path).to eq(CA_CERT_PATH)
  end

  it "uses APPSIGNAL_CA_FILE_PATH when configured" do
    ENV["APPSIGNAL_CA_FILE_PATH"] = "/path/to/appsignal-ca.pem"

    expect(ca_cert_path).to eq("/path/to/appsignal-ca.pem")
  end

  it "uses SSL_CERT_FILE when configured" do
    ENV["SSL_CERT_FILE"] = "/path/to/system-ca.pem"

    expect(ca_cert_path).to eq("/path/to/system-ca.pem")
  end

  it "prefers APPSIGNAL_CA_FILE_PATH over SSL_CERT_FILE" do
    ENV["APPSIGNAL_CA_FILE_PATH"] = "/path/to/appsignal-ca.pem"
    ENV["SSL_CERT_FILE"] = "/path/to/system-ca.pem"

    expect(ca_cert_path).to eq("/path/to/appsignal-ca.pem")
  end

  it "ignores blank environment values" do
    ENV["APPSIGNAL_CA_FILE_PATH"] = " "
    ENV["SSL_CERT_FILE"] = ""

    expect(ca_cert_path).to eq(CA_CERT_PATH)
  end
end
