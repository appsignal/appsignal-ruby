if defined?(PhusionPassenger)
  PhusionPassenger.on_event(:starting_worker_process) do |forked|
    Appsignal.agent.forked!
  end

  PhusionPassenger.on_event(:stopping_worker_process) do
    Appsignal.agent.shutdown(true)
  end
end
