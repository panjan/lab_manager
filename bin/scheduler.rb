$: << 'lib'
require 'bundler/setup'
require 'lab_manager'

LabManager.setup

loop do
  LabManager.config.providers.each do |provider|
    provider_class = "::Providers::#{provider.to_s.camelize}".constantize
    provider_class.send("filter_machines_to_be_scheduled", queued_machines: Compute.alive.where(provider: provider)).each do |machine|
      #sidekiq perform_async each machine
    end
  end

  sleep 5
end
