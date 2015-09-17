require 'spec_helper'
require 'sidekiq/testing'

describe LabManager::ActionWorker do
  let(:action_worker) { described_class.new }
  let(:compute)       { create(:compute, :v_sphere) }

  it 'locks the action before processing', sidekiq: true do
    action = compute.actions.create!(command: :create_vm)
    locked_by_thread = false
    thr = Thread.new do
      action.with_lock do
        locked_by_thread = true
        Thread.pass
        sleep 2
      end
    end
    Thread.pass until locked_by_thread

    expect do
      action_worker.perform(action.id)
    end.to raise_error(ActiveRecord::StatementInvalid)
    Thread.kill thr
  end

  context 'when a compute is in dead state' do
    it 'refuses to process given action when state=errored' do
      compute.fatal_error!
      action = compute.actions.create!(command: :create_vm)
      action_worker.perform(action.id)
      action.reload
      expect(action.state).to eq 'failed'
    end

    it 'refuses to process given action when state=terminating' do
      compute.fatal_error!
      action = compute.actions.create!(command: :create_vm)
      action_worker.perform(action.id)
      action.reload
      expect(action.state).to eq 'failed'
    end
  end

  context 'when passed action is not in pending state' do
    it 'refuses to process that action' do
      action = compute.actions.create!(command: :create_vm)
      action.pending!
      action_worker.perform(action.id)
      expect(action.reload.state).to eq 'failed'
    end
  end

  context 'when create_vm action is requested' do
    it 'calls create_vm method of vmware provider object' do
      action = compute.actions.create!(command: :create_vm)
      expect_any_instance_of(::Provider::VSphere).to receive(:create_vm)
      compute.enqueue
      compute.save!
      action_worker.perform(action.id)
    end
  end

  context 'when terminate action is requested' do
    it 'calls terminate method of vmware provider object' do
      compute.enqueue!
      action = compute.actions.create!(command: :create_vm)
      ::Provider::VSphere.any_instance.stub(:create_vm).and_return(true)
      action_worker.perform(action.id)
      p action.state
      p compute.state
      action = compute.actions.create!(command: :terminate)

      action_worker.perform(action.id)
    end
  end

end
