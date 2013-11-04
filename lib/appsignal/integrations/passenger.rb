if defined?(::PhusionPassenger)
  Appsignal.logger.info('Using Passenger')

  ::PhusionPassenger.on_event(:starting_worker_process) do |forked|
    Appsignal.logger.debug('starting worker process')
    Appsignal.agent.forked!
  end

  ::PhusionPassenger.on_event(:stopping_worker_process) do
    Appsignal.logger.debug('stopping worker process')
    Appsignal.agent.shutdown(true)
  end
end
