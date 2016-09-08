module DirectoryHelper
  def spec_dir
    APPSIGNAL_SPEC_DIR
  end

  def support_dir
    @support_dir ||= File.join(spec_dir, 'support')
  end

  def tmp_dir
    @tmp_dir ||= File.join(spec_dir, 'tmp')
  end

  def fixtures_dir
    @fixtures_dir ||= File.join(support_dir, 'fixtures')
  end
end
