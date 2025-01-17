require "rails_helper"

RSpec.describe "rendering locals in a partial" do
  context "when comment is low-quality" do
    it "renders the comment with low-quality marker" do
      allow(Settings::General).to receive(:mascot_image_url).and_return("https://i.imgur.com/fKYKgo4.png")
      article = create(:article)
      comment = create(:comment, processed_html: "hi", score: -100, commentable: article)

      render "comments/comment",
             comment: comment,
             commentable: article,
             is_view_root: true,
             is_childless: true,
             is_admin: false,
             subtree_html: ""

      expect(rendered).to match(/crayons-notice crayons-notice--warning low-quality-comment-marker/)
        .and match(%r{Comment marked as low quality/non-constructive by the community.})
      expect(rendered).to have_link "View Code of Conduct", href: "/code-of-conduct"
    end
  end
end
