require "rails_helper"

RSpec.describe NotificationSubscriptions::Unsubscribe, type: :service do
  let(:current_user) { create(:user) }
  let(:another_user) { create(:user) }
  let(:article) { create(:article, user: current_user) }
  let!(:subscription) { create(:notification_subscription, user: current_user, notifiable: article) }

  context "when a valid subscription ID is provided" do
    it "destroys the notification subscription" do
      result = nil # needs to exist before the block or Ruby won't set it

      expect do
        result = described_class.call(current_user, subscription.id)
      end.to change(NotificationSubscription, :count).by(-1)

      expect(NotificationSubscription.find_by(id: subscription.id)).to be_nil

      expect(result).to eq({ destroyed: true })
    end
  end

  context "when an invalid subscription ID is provided" do
    it "does not destroy any notification subscriptions" do
      result = nil # needs to exist before the block or Ruby won't set it
      expect do
        result = described_class.call(current_user, 9999)
      end.not_to change(NotificationSubscription, :count)

      expect(result).to eq({ errors: "Notification subscription not found" })
    end
  end

  context "when no subscription ID is provided" do
    it "does not destroy any notification subscriptions" do
      result = nil # needs to exist before the block or Ruby won't set it
      expect do
        result = described_class.call(current_user, nil)
      end.not_to change(NotificationSubscription, :count)

      expect(result).to eq({ errors: "Subscription ID is missing" })
    end
  end
end
