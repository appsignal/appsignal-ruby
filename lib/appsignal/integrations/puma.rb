if defined?(::Puma)
  Appsignal.logger.info('Loading Puma integration')

  if ::Puma.cli_config
    ::Puma.cli_config.options[:before_worker_shutdown] << Proc.new do |id|
      Appsignal.stop
    end
  end
end
