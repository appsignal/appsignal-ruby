if defined?(::Puma) && ::Puma.respond_to?(:cli_config)
  Appsignal.logger.info('Loading Puma integration')

  if ::Puma.cli_config
    ::Puma.cli_config.options[:before_worker_shutdown] << Proc.new do |id|
      Appsignal.stop
    end
  end
end
