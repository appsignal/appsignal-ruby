module SystemHelpers
  def recognize_as_heroku
    ENV['DYNO'] = 'dyno1'
    value = recognize_as_container :lxc do
      yield
    end
    ENV.delete 'DYNO'
    value
  end

  def recognize_as_container(file)
    org_cgroup_file = Appsignal::System::Container::CGROUP_FILE
    Appsignal::System::Container.send :remove_const, :CGROUP_FILE
    Appsignal::System::Container.send :const_set, :CGROUP_FILE,
      File.join(DirectoryHelper.fixtures_dir, 'containers', 'cgroups', file.to_s)

    value = yield

    Appsignal::System::Container.send :remove_const, :CGROUP_FILE
    Appsignal::System::Container.send :const_set, :CGROUP_FILE, org_cgroup_file

    value
  end
end
