module DirectoryHelper
  module_function

  def project_dir
    @project_dir ||= File.expand_path("..", spec_dir)
  end

  def spec_dir
    APPSIGNAL_SPEC_DIR
  end

  def support_dir
    @support_dir ||= File.join(spec_dir, "support")
  end

  def tmp_dir
    @tmp_dir ||= File.join(spec_dir, "tmp")
  end

  def fixtures_dir
    @fixtures_dir ||= File.join(support_dir, "fixtures")
  end

  def resources_dir
    @resources_dir ||= File.join(project_dir, "resources")
  end
end
