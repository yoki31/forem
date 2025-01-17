require "rails_helper"

RSpec.describe "UserNotificationSettings" do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "PUT /update/:id" do
    it "disables reaction notifications (in both users and notification_settings tables)" do
      expect(user.notification_setting.reaction_notifications).to be(true)

      expect do
        put users_notification_settings_path(user.notification_setting.id),
            params: { users_notification_setting: { tab: "notifications", reaction_notifications: 0 } }
      end.to change { user.notification_setting.reload.reaction_notifications }.from(true).to(false)
    end

    it "enables community-success notifications" do
      put users_notification_settings_path(user.notification_setting.id),
          params: { users_notification_setting: { tab: "notifications", mod_roundrobin_notifications: 1 } }
      expect(user.notification_setting.reload.mod_roundrobin_notifications).to be(true)
    end

    it "disables community-success notifications" do
      put users_notification_settings_path(user.notification_setting.id),
          params: { users_notification_setting: { tab: "notifications", mod_roundrobin_notifications: 0 } }
      expect(user.notification_setting.reload.mod_roundrobin_notifications).to be(false)
    end

    it "can toggle welcome notifications" do
      put users_notification_settings_path(user.notification_setting.id),
          params: { users_notification_setting: { tab: "notifications", welcome_notifications: 0 } }
      expect(user.notification_setting.reload.subscribed_to_welcome_notifications?).to be(false)

      put users_notification_settings_path(user.notification_setting.id),
          params: { users_notification_setting: { tab: "notifications", welcome_notifications: 1 } }
      expect(user.notification_setting.reload.subscribed_to_welcome_notifications?).to be(true)
    end
  end
end
