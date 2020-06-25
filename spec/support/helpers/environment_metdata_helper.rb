module EnvironmentMetadataHelper
  def capture_environment_metadata_report_calls
    allow(Appsignal::Extension).to receive(:set_environment_metadata)
      .and_call_original
  end

  def expect_environment_metadata(key, value)
    expect(Appsignal::Extension).to have_received(:set_environment_metadata)
      .with(key, value)
  end

  def expect_not_environment_metadata(key)
    expect(Appsignal::Extension).to_not have_received(:set_environment_metadata)
      .with(key, anything)
  end
end
