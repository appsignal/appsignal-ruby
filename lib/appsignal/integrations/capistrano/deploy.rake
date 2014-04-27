namespace :appsignal do
  desc 'Notify AppSignal of this deploy'
  task :deploy do
    on roles(fetch(:appsignal_roles, :app)) do
      notifier = Appsignal::Integrations::Capistrano::Notifier.new({
        config: fetch(:appsignal_config, {}),
        env: fetch(:rails_env, 'production'),
        revision: fetch(:current_revision) || fetch_revision,
        repo_url: fetch(:repo_url),
        logger: self
      })
      notifier.notify
    end
  end
end

begin
  after 'deploy', 'appsignal:deploy'
rescue
end
