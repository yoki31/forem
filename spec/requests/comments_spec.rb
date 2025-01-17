require "rails_helper"
require "requests/shared_examples/comment_hide_or_unhide_request"

RSpec.describe "Comments" do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:article) { create(:article, user: user) }
  let(:podcast) { create(:podcast) }
  let(:podcast_episode) { create(:podcast_episode, podcast_id: podcast.id) }
  let!(:comment) { create(:comment, commentable: article, user: user) }

  describe "GET comment index" do
    it "returns 200" do
      get comment.path
      expect(response).to have_http_status(:ok)
    end

    it "displays a comment" do
      get comment.path
      expect(response.body).to include(comment.processed_html)
    end

    context "when there are comments with different score" do
      let!(:spam_comment) do
        create(:comment, commentable: article, user: user, score: -1000, body_markdown: "spammer-comment")
      end
      let!(:mediocre_comment) do
        create(:comment, commentable: article, user: user, score: -50, body_markdown: "mediocre-comment")
      end

      before do
        create(:comment, commentable: article, user: user, score: -100, body_markdown: "bad-comment")
        create(:comment, commentable: article, user: user, score: 10, body_markdown: "good-comment")
      end

      it "displays all comments except for below -400 score for signed in", :aggregate_failures do
        sign_in user
        get "#{article.path}/comments"
        expect(response.body).to include("mediocre-comment")
        expect(response.body).to include("low quality") # marker
        expect(response.body).to include("bad-comment")
        expect(response.body).to include("good-comment")
        expect(response.body).not_to include("spammer-comment")
      end

      it "displays deleted message and children of a spam comment for signed in", :aggregate_failures do
        create(:comment, user: user, parent: spam_comment, commentable: article,
                         body_markdown: "child-of-a-spam-comment")
        sign_in user
        get "#{article.path}/comments"
        expect(response.body).not_to include("spammer-comment")
        expect(response.body).to include("Comment deleted")
        expect(response.body).to include("child-of-a-spam-comment")
      end

      it "displays only comments with positive score for signed out user", :aggregate_failures do
        get "#{article.path}/comments"
        expect(response.body).not_to include("mediocre-comment")
        expect(response.body).not_to include("bad-comment")
        expect(response.body).to include("good-comment")
        expect(response.body).not_to include("spammer-comment")
      end

      it "doesn't display children of negative comments for signed out user" do
        create(:comment, user: user, parent: mediocre_comment, commentable: article,
                         body_markdown: "child-of-a-negative-comment")
        get "#{article.path}/comments"
        expect(response.body).not_to include("child-of-a-negative-comment")
      end
    end

    context "when there are child spam comments" do
      it "hides child spam comment if it has no children" do
        create(:comment, commentable: article, score: -500, body_markdown: "child-spam-comment", parent: comment)
        sign_in user
        get "#{article.path}/comments"
        expect(response.body).not_to include("child-spam-comment")
        expect(response.body).not_to include("Comment deleted")
      end
    end

    context "when the comment is a root" do
      it "displays the comment hidden message if the comment is hidden" do
        comment.update(hidden_by_commentable_user: true)
        get comment.path
        hidden_comment_message = "Comment hidden by post author - thread only visible in this permalink"
        expect(response.body).to include(hidden_comment_message)
      end

      it "displays the comment anyway if it is hidden" do
        comment.update(hidden_by_commentable_user: true)
        get comment.path
        expect(response.body).to include(comment.processed_html)
      end

      it "displays noindex if comment has score of less than 0" do
        comment.update_column(:score, -5)
        get comment.path
        expect(response.body).to include('<meta name="googlebot" content="noindex">')
      end

      it "does not display noindex if comment has 0 or more score" do
        get comment.path
        expect(response.body).not_to include('<meta name="googlebot" content="noindex">')
      end

      it "displays noindex if commentable has score of less than 0" do
        comment.commentable.update_column(:score, -5)
        get comment.path
        expect(response.body).to include('<meta name="googlebot" content="noindex">')
      end

      it "displays child comment if it's not hidden" do
        child_comment = create(:comment, parent: comment, user: user, commentable: article)
        comment.update(hidden_by_commentable_user: true)
        get comment.path
        expect(response.body).to include(child_comment.processed_html)
      end
    end

    context "when the comment is a child comment" do
      let(:child) { create(:comment, parent: comment, commentable: article, user: user) }

      it "displays proper button and text for child comment" do
        get child.path
        expect(response.body).to include(CGI.escapeHTML(comment.title(150)))
        expect(response.body).to include(child.processed_html)
      end
    end

    context "when the comment is two levels nested and hidden" do # child of a child
      let(:child) { create(:comment, parent: comment, commentable: article, user: user) }
      let(:child_of_child) do
        create(:comment, parent_id: child.id, commentable: article, user: user, hidden_by_commentable_user: true)
      end

      it "does not display the hidden comment in the child's permalink" do
        get child.path
        expect(response.body).not_to include(child_of_child.processed_html)
      end

      it "does not display the hidden comment in the article's comments section" do
        get "#{article.path}/comments"
        expect(response.body).not_to include(child_of_child.processed_html)
      end
    end

    context "when the comment is a sibling of a child comment and is hidden" do
      let(:child) { create(:comment, parent: comment, commentable: article, user: user) }
      let(:sibling) do
        create(:comment, parent: comment, commentable: article, user: user, hidden_by_commentable_user: true)
      end

      it "does not display the hidden comment in the article's comments section" do
        get "#{article.path}/comments"
        expect(response.body).not_to include(sibling.processed_html)
      end

      it "shows the hidden comments message in the comment's permalink" do
        get sibling.path
        hidden_comment_message = "Comment hidden by post author - thread only visible in this permalink"
        expect(response.body).to include(hidden_comment_message)
      end

      it "does not show the sibling comment in the child's comment permalink" do
        get child.path
        expect(response.body).not_to include(sibling.processed_html)
      end

      it "shows the comment in the permalink" do
        get sibling.path
        expect(response.body).to include(sibling.processed_html)
      end
    end

    context "when the comment is three levels nested and hidden" do # child of a child of a child
      let(:child) { create(:comment, parent: comment, commentable: article, user: user) }
      let(:second_level_child) { create(:comment, parent: child, commentable: article, user: user) }
      let(:third_level_child) do
        create(:comment, parent: second_level_child, commentable: article, user: user, hidden_by_commentable_user: true)
      end
      let(:fourth_level_child) do
        create(:comment, parent_id: third_level_child.id, commentable: article, user: user)
      end

      # When opening a hidden comment by a permalink we want to see the full thread including hidden comments.
      it "shows hidden child comments in its parent's permalink when parent is also hidden" do
        third_level_child
        child.update_column(:hidden_by_commentable_user, true)
        get child.path
        expect(response.body).to include(third_level_child.processed_html)
      end

      it "shows the hidden comment's child in its parent's permalink if the child is not hidden explicitly" do
        fourth_level_child
        get second_level_child.path
        expect(response.body).to include(fourth_level_child.processed_html)
      end

      it "shows the comment in the permalink" do
        get third_level_child.path
        expect(response.body).to include(third_level_child.processed_html)
      end

      it "shows the fourth level child in the hidden comment's permalink" do
        fourth_level_child
        get third_level_child.path
        expect(response.body).to include(fourth_level_child.processed_html)
      end
    end

    context "when the comment is low quality and below hiding threshold" do
      let(:low_comment) do
        create(:comment, commentable: article, user: user, score: -1000, body_markdown: "low-comment")
      end

      it "raises 404 when no children" do
        expect do
          get low_comment.path
        end.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "renders success when no children + admin signed in", :aggregate_failures do
        sign_in admin
        get low_comment.path
        expect(response).to be_successful
        expect(response.body).to include("low-comment")
      end

      it "raises 404 when has children and not signed in" do
        create(:comment, commentable: article, user: user, parent: low_comment,
                         body_markdown: "child of a low-quality comment")
        expect do
          get low_comment.path
        end.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "raises 404 when no children + user signed in" do
        sign_in user
        expect do
          get low_comment.path
        end.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "is displayed as deleted when has children + user signed in", :aggregate_failures do
        create(:comment, commentable: article, user: user, parent: low_comment,
                         body_markdown: "child of a low-quality comment")
        sign_in user
        get low_comment.path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Comment deleted")
        expect(response.body).to include("child of a low-quality comment")
      end

      it "displays text when there are children + admin signed in", :aggregate_failures do
        create(:comment, commentable: article, user: user, parent: low_comment,
                         body_markdown: "child of a low-quality comment")
        sign_in admin
        get low_comment.path
        expect(response).to be_successful
        expect(response.body).to include("low-comment")
        expect(response.body).to include("child of a low-quality comment")
      end

      it "hides negative children for signed out" do
        create(:comment, commentable: article, user: user, score: -10, parent: comment,
                         body_markdown: "low-child of a comment")
        get comment.path
        expect(response.body).not_to include("low-child of a comment")
      end
    end

    context "when the comment is low quality and above hiding threshold" do
      let(:low_comment) do
        create(:comment, commentable: article, user: user, score: -100, body_markdown: "low-comment")
      end

      it "raises 404 when no children + not signed in" do
        expect do
          get low_comment.path
        end.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "raises 404 when has children and not signed in" do
        create(:comment, commentable: article, user: user, parent: low_comment,
                         body_markdown: "child of a low-quality comment")
        expect do
          get low_comment.path
        end.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "is displayed with a low quality marker when user signed in" do
        sign_in user
        get low_comment.path
        expect(response).to be_successful
        expect(response.body).to include("low quality")
      end
    end

    context "when the comment is for a podcast's episode" do
      let!(:podcast_comment) { create(:comment, commentable: podcast_episode, user: user) }

      it "is successful" do
        get podcast_comment.path
        expect(response).to have_http_status(:ok)
      end

      it "raises 404 when low quality" do
        podcast_comment.update_column(:score, -500)
        expect do
          get podcast_comment.path
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when the article is unpublished" do
      before do
        new_markdown = article.body_markdown.gsub("published: true", "published: false")
        comment
        article.update(body_markdown: new_markdown)
      end

      it "raises a Not Found error" do
        expect { get comment.path }.to raise_error("Not Found")
      end
    end

    context "when the article is deleted" do
      it "raises not found when listing article comments" do
        path = "#{article.path}/comments"

        article.destroy

        expect { get path }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "shows comment from a deleted post" do
        article.destroy

        get comment.path
        expect(response.body).to include("Comment from a deleted post")
      end
    end

    context "when the podcast episode is deleted" do
      it "renders deleted_commentable_comment view" do
        podcast_comment = create(:comment, commentable: podcast_episode)
        podcast_episode.destroy

        get podcast_comment.path
        expect(response.body).to include("Comment from a deleted post")
      end
    end
  end

  describe "GET /:username/:slug/comments/:id_code/edit" do
    context "when not logged-in" do
      it "raises unauthorized error" do
        expect do
          get "/#{user.username}/#{article.slug}/comments/#{comment.id_code_generated}/edit"
        end.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context "when logged-in" do
      before do
        sign_in user
      end

      it "returns 200" do
        get "/#{user.username}/#{article.slug}/comments/#{comment.id_code_generated}/edit"
        expect(response).to have_http_status(:ok)
      end

      it "returns the comment" do
        get "/#{user.username}/#{article.slug}/comments/#{comment.id_code_generated}/edit"
        expect(response.body).to include CGI.escapeHTML(comment.body_markdown)
      end
    end

    context "when the article is deleted" do
      before do
        sign_in user
      end

      it "edit action returns 200" do
        article = create(:article, user: user)
        comment = create(:comment, commentable: article, user: user)

        article.destroy

        get "/#{user.username}/#{article.slug}/comments/#{comment.id_code_generated}/edit"
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "PUT /comments/:id" do
    before do
      sign_in user
    end

    it "does not raise a StandardError for invalid liquid tags" do
      put "/comments/#{comment.id}",
          params: { comment: { body_markdown: "{% gist flsnjfklsd %}" } }

      expect(response).to have_http_status(:ok)
      expect(flash[:error]).not_to be_nil
    end

    context "when the article is deleted" do
      it "updates body markdown" do
        article = create(:article, user: user)
        comment = create(:comment, commentable: article, user: user)

        article.destroy

        params = { comment: { body_markdown: "{edited comment}" } }
        put "/comments/#{comment.id}", params: params

        comment.reload
        expect(comment.processed_html).to include("edited comment")
      end
    end
  end

  describe "POST /comments/preview" do
    it "returns 401 if user is not logged in" do
      post "/comments/preview",
           params: { comment: { body_markdown: "hi" } },
           headers: { HTTP_ACCEPT: "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end

    context "when logged-in and consistent rendering" do
      before do
        sign_in user
        post "/comments/preview",
             params: { comment: { body_markdown: "hi" } },
             headers: { HTTP_ACCEPT: "application/json" }
      end

      it "returns 200 on good request" do
        expect(response).to have_http_status(:ok)
      end

      it "returns json" do
        expect(response.media_type).to eq("application/json")
      end
    end
  end

  describe "POST /comments" do
    let(:base_comment_params) do
      {
        comment: {
          commentable_id: article.id,
          commentable_type: "Article",
          user: user,
          body_markdown: "New comment #{rand(10)}"
        }
      }
    end

    context "when a user is comment_suspended" do
      before do
        sign_in user
        user.add_role(:comment_suspended)
      end

      it "returns not authorized" do
        post "/comments", params: base_comment_params
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when part of field test" do
      before do
        sign_in user
        allow(Users::RecordFieldTestEventWorker).to receive(:perform_async)
      end

      it "converts field test" do
        post "/comments", params: base_comment_params

        expected_args = [user.id, "user_creates_comment"]
        expect(Users::RecordFieldTestEventWorker).to have_received(:perform_async).with(*expected_args)
      end
    end

    context "when not part of field test" do
      before do
        sign_in user
        allow(FieldTest).to receive(:config).and_return({ "experiments" => nil })
        allow(Users::RecordFieldTestEventWorker).to receive(:perform_async)
      end

      it "converts field test" do
        post "/comments", params: base_comment_params

        expect(Users::RecordFieldTestEventWorker).not_to have_received(:perform_async)
      end

      it "records a feed event for articles reached through a feed" do
        create(:feed_event, category: :click, article: article, user: user)

        expect { post "/comments", params: base_comment_params }
          .to change(FeedEvent, :count).by(1)
        expect(user.feed_events.last).to have_attributes(
          category: "comment",
          article_id: article.id,
          user_id: user.id,
        )
      end

      it "does not record a feed event for articles that were not reached through a feed" do
        # activity by a different user!
        create(:feed_event, category: :click, article: article, user: create(:user))

        expect { post "/comments", params: base_comment_params }
          .not_to change(FeedEvent, :count)
        expect(user.feed_events).to be_empty
      end

      it "does not record a feed event for a comment on a podcast episode" do
        podcast_episode_params = {
          comment: {
            commentable_id: podcast_episode.id,
            commentable_type: "PodcastEpisode"
          }
        }

        expect do
          post "/comments",
               params: base_comment_params.merge(podcast_episode_params)
        end.not_to change(FeedEvent, :count)

        expect(user.feed_events).to be_empty
      end
    end
  end

  describe "PATCH /comments/:comment_id/hide" do
    include_examples "PATCH /comments/:comment_id/hide or unhide", path: "hide", hidden: "true"

    context "with notifications" do
      let(:user2) { create(:user) }
      let(:article)  { create(:article, :with_notification_subscription, user: user) }
      let(:comment)  { create(:comment, commentable: article, user: user2) }

      before do
        sign_in user
        Notification.send_new_comment_notifications_without_delay(comment)
      end

      it "Delete notification when comment is hidden" do
        notification = user.notifications.last
        patch "/comments/#{comment.id}/hide", headers: { HTTP_ACCEPT: "application/json" }
        expect(Notification.exists?(id: notification.id)).to be(false)
      end

      it "deletes children notification when comment is hidden" do
        child_comment = create(:comment, commentable: article, user: user2, parent: comment)
        Notification.send_new_comment_notifications_without_delay(child_comment)
        notification = child_comment.notifications.last
        patch "/comments/#{comment.id}/hide", params: { hide_children: "1" },
                                              headers: { HTTP_ACCEPT: "application/json" }
        child_comment.reload
        expect(child_comment.hidden_by_commentable_user).to be true
        expect(Notification.exists?(id: notification.id)).to be(false)
      end
    end

    context "with hiding child comments" do
      let(:commentable_author) { create(:user) }
      let(:article) { create(:article, user: commentable_author) }
      let(:parent_comment) { create(:comment, commentable: article, user: commentable_author) }
      let!(:child_comment) { create(:comment, commentable: article, parent: parent_comment) }

      before do
        sign_in commentable_author
      end

      it "hides child comment when hide_children is passed" do
        patch "/comments/#{parent_comment.id}/hide", params: { hide_children: "1" },
                                                     headers: { HTTP_ACCEPT: "application/json" }
        child_comment.reload
        expect(child_comment.hidden_by_commentable_user).to be true
      end

      it "hides second level child if hide_children is passed" do
        second_level_child = create(:comment, parent: child_comment, commentable: article, user: user)
        patch "/comments/#{parent_comment.id}/hide", params: { hide_children: "1" },
                                                     headers: { HTTP_ACCEPT: "application/json" }
        second_level_child.reload
        expect(second_level_child.hidden_by_commentable_user).to be true
      end

      it "hides child comment when hide_children is not passed" do
        patch "/comments/#{parent_comment.id}/hide", params: { hide_children: "0" },
                                                     headers: { HTTP_ACCEPT: "application/json" }
        child_comment.reload
        expect(child_comment.hidden_by_commentable_user).to be false
      end
    end

    context "with comment by staff account" do
      let(:staff_account) { create(:user) }
      let(:commentable_author) { create(:user) }
      let(:article) { create(:article, user: commentable_author) }
      let(:comment) { create(:comment, commentable: article, user: staff_account) }

      before do
        allow(User).to receive(:staff_account).and_return(staff_account)
        sign_in commentable_author
      end

      it "does not permit hiding the comment" do
        expect do
          patch "/comments/#{comment.id}/hide", headers: { HTTP_ACCEPT: "application/json" }
        end.to raise_error(Pundit::NotAuthorizedError)

        comment.reload
        expect(comment.hidden_by_commentable_user).to be false
      end
    end
  end

  describe "PATCH /comments/:comment_id/unhide" do
    include_examples "PATCH /comments/:comment_id/hide or unhide", path: "unhide", hidden: "false"
  end

  describe "DELETE /comments/:comment_id" do
    # we're using local article and comments, to avoid removing data used by other tests,
    # which will incur in ordering issues
    let!(:article) { create(:article, user: user) }
    let!(:comment) { create(:comment, commentable: article, user: user) }

    before { sign_in user }

    it "deletes a comment if the article is still present" do
      delete "/comments/#{comment.id}"

      expect(Comment.find_by(id: comment.id)).to be_nil
      expect(response).to redirect_to(comment.commentable.path)
      expect(flash[:notice]).to eq("Comment was successfully deleted.")
    end

    it "deletes a comment if the article has been deleted" do
      article.destroy!

      delete "/comments/#{comment.id}"

      expect(Comment.find_by(id: comment.id)).to be_nil
      expect(response).to redirect_to(user_path(user))
      expect(flash[:notice]).to eq("Comment was successfully deleted.")
    end
  end
end
