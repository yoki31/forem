require "rails_helper"

RSpec.describe BillboardEventRollupWorker, type: :worker do
  subject(:worker) { described_class.new }

  before do
    allow(BillboardEventRollup).to receive(:rollup)
  end

  include_examples "#enqueues_on_correct_queue", "low_priority"

  describe "#perform" do
    it "rollups one month ago" do
      month_ago = Date.current - 32.days
      worker.perform
      expect(BillboardEventRollup).to have_received(:rollup).with(month_ago)
    end
  end
end
