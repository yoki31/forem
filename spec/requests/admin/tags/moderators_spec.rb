require "rails_helper"

RSpec.describe "/admin/content_manager/tags/:id/moderator" do
  let(:super_admin) { create(:user, :super_admin) }
  let(:user)        { create(:user) }
  let(:tag)         { create(:tag) }

  describe "POST /admin/content_manager/tags/:id/moderator" do
    before { sign_in super_admin }

    it "adds the given user as trusted and as a tag moderator by username" do
      post admin_tag_moderator_path(tag.id), params: { tag_id: tag.id, tag: { username: user.username } }

      expect(user.tag_moderator?(tag: tag)).to be true
      expect(user.trusted?).to be true
    end

    it "updates user's email_tag_mod_newsletter setting" do
      user.notification_setting.update_column(:email_tag_mod_newsletter, false)
      expect do
        post admin_tag_moderator_path(tag.id), params: { tag_id: tag.id, tag: { username: user.username } }
      end.to change { user.reload.notification_setting.email_tag_mod_newsletter }.from(false).to(true)
    end

    it "redirects to edit with not_found message when there is no such username" do
      post admin_tag_moderator_path(tag.id), params: { tag_id: tag.id, tag: { username: "any_username" } }

      expect(response).to redirect_to(edit_admin_tag_path(tag.id))
      expect(flash[:error]).to include("Username \"any_username\" was not found")
    end

    it "displays error message when notification settings are not updated" do
      result = instance_double(TagModerators::Add::Result, success?: false, errors: "invalid setting")
      allow(TagModerators::Add).to receive(:call).with(user.id, tag.id.to_s).and_return(result)

      post admin_tag_moderator_path(tag.id), params: { tag_id: tag.id, tag: { username: user.username } }
      expect(flash[:error]).to include("or their account has errors: invalid setting")
    end
  end

  describe "DELETE /admin/content_manager/tags/:id/moderator" do
    before do
      sign_in super_admin
      user.add_role(:trusted)
      user.add_role(:tag_moderator, tag)
    end

    it "removes the tag moderator role from the user" do
      delete admin_tag_moderator_path(tag.id), params: { tag_id: tag.id, tag: { user_id: user.id } }
      expect(user.tag_moderator?).to be false
    end

    it "does not remove the trusted role from the user" do
      delete admin_tag_moderator_path(tag.id), params: { tag_id: tag.id, tag: { user_id: user.id } }
      expect(user.trusted?).to be true
    end
  end
end
