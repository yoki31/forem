require "rails_helper"

RSpec.describe "Api::V1::Users" do
  let(:api_secret) { create(:api_secret) }
  let(:headers) { { "Accept" => "application/vnd.forem.api-v1+json" } }
  let(:auth_headers) { headers.merge({ "api-key" => api_secret.secret }) }
  let(:listener) { :admin_api }

  describe "GET /api/users/:id" do
    let!(:user) do
      create(:user,
             profile_image: "",
             _skip_creating_profile: true,
             profile: create(:profile, summary: "Something something"))
    end

    it "returns 404 if the user id is not found" do
      get api_user_path("invalid-id"), headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 if the user username is not found" do
      get api_user_path("by_username"), params: { url: "invalid-username" }, headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 if the user is not registered" do
      user.update_column(:registered, false)
      get api_user_path(user.id), headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 200 if the user username is found" do
      get api_user_path("by_username"), params: { url: user.username }, headers: headers
      expect(response).to have_http_status(:ok)
    end

    it "returns unauthenticated if no authentication and the Forem instance is set to private" do
      allow(Settings::UserExperience).to receive(:public).and_return(false)
      get api_user_path("by_username"), params: { url: user.username }, headers: headers
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns the correct json representation of the user", :aggregate_failures do
      get api_user_path(user.id), headers: headers

      response_user = response.parsed_body

      expect(response_user["type_of"]).to eq("user")

      %w[id username name twitter_username github_username].each do |attr|
        expect(response_user[attr]).to eq(user.public_send(attr))
      end

      %w[summary website_url location].each do |attr|
        expect(response_user[attr]).to eq(user.profile.public_send(attr))
      end

      expect(response_user["joined_at"]).to eq(user.created_at.strftime("%b %e, %Y"))
      expect(response_user["profile_image"]).to eq(user.profile_image_url_for(length: 320))
      expect(response_user["badge_ids"]).to eq(user.badge_ids)
      expect(response_user.key?("followers_count")).to be false
    end

    it "includes email if display_email_on_profile is set to true" do
      user.setting.update_column(:display_email_on_profile, true)
      get api_user_path("by_username"), params: { url: user.username }, headers: headers
      response_user = response.parsed_body
      expect(response_user["email"]).to eq(user.email)
    end

    it "doesn't include email if display_email_on_profile is false" do
      get api_user_path("by_username"), params: { url: user.username }, headers: headers
      response_user = response.parsed_body
      expect(response_user.key?("email")).to be true
      expect(response_user["email"]).to be_nil
    end

    it "includes badge_ids" do
      achievement = create(:badge_achievement, user: user)
      badge_ids = [achievement.badge_id]
      get api_user_path("by_username"), params: { url: user.username }, headers: headers
      response_user = response.parsed_body
      expect(response_user["badge_ids"]).to eq(badge_ids)
    end
  end

  describe "GET /api/users/me" do
    context "when unauthenticated" do
      it "returns unauthorized" do
        get me_api_users_path, headers: headers
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when unauthorized" do
      it "returns unauthorized" do
        get me_api_users_path, headers: headers.merge({ "api-key" => "invalid api key" })
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when request is authenticated" do
      let(:user) { api_secret.user }

      it "returns the correct json representation of the user", :aggregate_failures do
        create(:badge_achievement, user: user)

        get me_api_users_path, headers: auth_headers

        expect(response).to have_http_status(:ok)
        response_user = response.parsed_body

        expect(response_user["type_of"]).to eq("user")

        %w[id username name twitter_username github_username].each do |attr|
          expect(response_user[attr]).to eq(user.public_send(attr))
        end

        %w[summary website_url location].each do |attr|
          expect(response_user[attr]).to eq(user.profile.public_send(attr))
        end

        expect(response_user["joined_at"]).to eq(user.created_at.strftime("%b %e, %Y"))
        expect(response_user["profile_image"]).to eq(user.profile_image_url_for(length: 320))

        expect(response_user["badge_ids"]).to eq(user.badge_ids)
        expect(response_user["followers_count"]).to eq(user.followers_count)
      end

      it "returns 200 if no authentication and the Forem instance is set to private but user is authenticated" do
        allow(Settings::UserExperience).to receive(:public).and_return(false)
        get me_api_users_path, headers: auth_headers

        response_user = response.parsed_body

        expect(response_user["type_of"]).to eq("user")

        %w[id username name twitter_username github_username].each do |attr|
          expect(response_user[attr]).to eq(user.public_send(attr))
        end

        %w[summary website_url location].each do |attr|
          expect(response_user[attr]).to eq(user.profile.public_send(attr))
        end

        expect(response_user["joined_at"]).to eq(user.created_at.strftime("%b %e, %Y"))
        expect(response_user["profile_image"]).to eq(user.profile_image_url_for(length: 320))
      end

      it "returns followers_count" do
        create(:follow, followable: user)
        get me_api_users_path, headers: auth_headers
        response_user = response.parsed_body
        expect(response_user["followers_count"]).to eq(1)
      end

      it "doesn't include spammers in followers_count" do
        follower = create(:user, :spam)
        create(:follow, followable: user, follower: follower)
        get me_api_users_path, headers: auth_headers
        response_user = response.parsed_body
        expect(response_user["followers_count"]).to eq(0)
      end
    end
  end

  describe "GET /api/users/search", :aggregate_failures do
    let!(:user) { create(:user) }

    context "when unauthenticated" do
      it "returns unauthorized" do
        get api_users_search_path(email: user.email),
            headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when unauthorized" do
      it "returns unauthorized if api key is invalid" do
        get api_users_search_path(email: user.email),
            headers: headers.merge({ "api-key" => "invalid api key" })

        expect(response).to have_http_status(:unauthorized)
      end

      it "returns unauthorized if api key belongs to non-admin user" do
        get api_users_search_path(email: user.email),
            headers: auth_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when request is authenticated" do
      before { api_secret.user.add_role(:super_admin) }

      it "returns 200 when finds a user" do
        get api_users_search_path(email: user.email), headers: auth_headers
        expect(response).to have_http_status(:ok)
      end

      it "finds a user" do
        get api_users_search_path(email: user.email), headers: auth_headers

        response_user = response.parsed_body
        expect(response_user["type_of"]).to eq("user")
        %w[id username name twitter_username github_username].each do |attr|
          expect(response_user[attr]).to eq(user.public_send(attr))
        end
      end

      it "returns not found when no email is passed" do
        get api_users_search_path, headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end

      it "returns not found when user is not found" do
        get api_users_search_path(email: "hello@hello.edu"), headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PUT /api/users/:id/unpublish", :aggregate_failures do
    let(:target_user) { create(:user) }
    let!(:target_articles) { create_list(:article, 3, user: target_user, published: true) }
    let!(:target_comments) { create_list(:comment, 3, user: target_user) }

    before { Audit::Subscribe.listen listener }

    after { Audit::Subscribe.forget listener }

    context "when unauthenticated" do
      it "returns unauthorized" do
        put api_user_unpublish_path(id: target_user.id),
            headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when unauthorized" do
      it "returns unauthorized if api key is invalid" do
        put api_user_unpublish_path(id: target_user.id),
            headers: headers.merge({ "api-key" => "invalid api key" })

        expect(response).to have_http_status(:unauthorized)
      end

      it "returns unauthorized if api key belongs to non-admin user" do
        put api_user_unpublish_path(id: target_user.id),
            headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when request is authenticated" do
      before { api_secret.user.add_role(:super_admin) }

      it "is successful in unpublishing a user's comments and articles", :aggregate_failures do
        # User's articles are published and comments exist
        expect(target_articles.map(&:published?)).to contain_exactly(true, true, true)
        expect(target_comments.map(&:deleted)).to contain_exactly(false, false, false)

        sidekiq_perform_enqueued_jobs(only: Moderator::UnpublishAllArticlesWorker) do
          put api_user_unpublish_path(id: target_user.id), headers: auth_headers
        end

        expect(response).to have_http_status(:no_content)

        # Ensure article's aren't published and comments deleted
        # (with boolean attribute so they can be reverted if needed)
        expect(target_articles.map { |a| a.reload.published? }).to contain_exactly(false, false, false)
        expect(target_comments.map { |c| c.reload.deleted }).to contain_exactly(true, true, true)
      end

      it "creates an audit log of the action taken" do
        # These deleted comments/articles are important so that the AuditLog trail won't
        # include previously deleted resources like these in the log. Otherwise the revert
        # action on these would have unintended consequences, i.e. revert a delete/unpublish
        # that wasn't affected by the action taken in the API endpoint request.
        create(:article, user: target_user, published: false)
        create(:comment, user: target_user, deleted: true)

        sidekiq_perform_enqueued_jobs(only: Moderator::UnpublishAllArticlesWorker) do
          put api_user_unpublish_path(id: target_user.id), headers: auth_headers
        end

        log = AuditLog.last
        expect(log.category).to eq(AuditLog::ADMIN_API_AUDIT_LOG_CATEGORY)
        expect(log.data["action"]).to eq("api_user_unpublish")
        expect(log.user_id).to eq(api_secret.user.id)

        # These ids match the affected articles/comments and not the ones created above
        expect(log.data["target_article_ids"]).to match_array(target_articles.map(&:id))
        expect(log.data["target_comment_ids"]).to match_array(target_comments.map(&:id))
      end

      it "creates a note when note text is passed" do
        sidekiq_perform_enqueued_jobs(only: Moderator::UnpublishAllArticlesWorker) do
          expect do
            put api_user_unpublish_path(id: target_user.id, note: "hehe"), headers: auth_headers
          end.to change(Note, :count).by(1)
        end
        note = target_user.notes.last
        expect(note.content).to eq("hehe")
        expect(note.reason).to eq("unpublish_all_articles")
      end

      it "creates a note with the default text when note text is not passed" do
        sidekiq_perform_enqueued_jobs(only: Moderator::UnpublishAllArticlesWorker) do
          expect do
            put api_user_unpublish_path(id: target_user.id), headers: auth_headers
          end.to change(Note, :count).by(1)
        end
        note = target_user.notes.last
        expect(note.content).to eq("#{api_secret.user.username} requested unpublish all articles via API")
        expect(note.reason).to eq("unpublish_all_articles")
      end
    end
  end
end
