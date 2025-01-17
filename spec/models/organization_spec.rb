require "rails_helper"

RSpec.describe Organization do
  let(:organization) { create(:organization) }

  describe "validations" do
    describe "builtin validations" do
      subject { organization }

      it { is_expected.to have_many(:articles).dependent(:nullify) }
      it { is_expected.to have_many(:collections).dependent(:nullify) }
      it { is_expected.to have_many(:credits).dependent(:restrict_with_error) }
      it { is_expected.to have_many(:billboards).dependent(:destroy) }
      it { is_expected.to have_many(:listings).dependent(:destroy) }
      it { is_expected.to have_many(:notifications).dependent(:delete_all) }
      it { is_expected.to have_many(:organization_memberships).dependent(:delete_all) }
      it { is_expected.to have_many(:profile_pins).dependent(:destroy) }
      it { is_expected.to have_many(:unspent_credits).class_name("Credit") }
      it { is_expected.to have_many(:users).through(:organization_memberships) }

      it { is_expected.to validate_length_of(:company_size).is_at_most(7) }
      it { is_expected.to validate_length_of(:cta_body_markdown).is_at_most(256) }
      it { is_expected.to validate_length_of(:cta_button_text).is_at_most(20) }
      it { is_expected.to validate_length_of(:email).is_at_most(64) }
      it { is_expected.to validate_length_of(:github_username).is_at_most(50) }
      it { is_expected.to validate_length_of(:location).is_at_most(64) }
      it { is_expected.to validate_length_of(:name).is_at_most(50) }
      it { is_expected.to validate_length_of(:proof).is_at_most(1500) }
      it { is_expected.to validate_length_of(:secret).is_equal_to(100) }
      it { is_expected.to validate_length_of(:slug).is_at_least(2).is_at_most(30) }
      it { is_expected.to validate_length_of(:story).is_at_most(640) }
      it { is_expected.to validate_length_of(:summary).is_at_most(250) }
      it { is_expected.to validate_length_of(:tag_line).is_at_most(60) }
      it { is_expected.to validate_length_of(:tech_stack).is_at_most(640) }
      it { is_expected.to validate_length_of(:twitter_username).is_at_most(15) }
      it { is_expected.to validate_length_of(:url).is_at_most(200) }
      it { is_expected.to validate_presence_of(:articles_count) }
      it { is_expected.to validate_presence_of(:credits_count) }
      it { is_expected.to validate_presence_of(:name) }
      it { is_expected.to validate_presence_of(:profile_image) }
      it { is_expected.to validate_presence_of(:slug) }
      it { is_expected.to validate_presence_of(:spent_credits_count) }
      it { is_expected.to validate_presence_of(:unspent_credits_count) }
      it { is_expected.to validate_uniqueness_of(:secret).allow_nil }
      it { is_expected.to validate_uniqueness_of(:slug).case_insensitive }

      it { is_expected.not_to allow_value("#xyz").for(:bg_color_hex) }
      it { is_expected.not_to allow_value("#xyz").for(:text_color_hex) }
      it { is_expected.to allow_value("#aabbcc").for(:bg_color_hex) }
      it { is_expected.to allow_value("#aabbcc").for(:text_color_hex) }
      it { is_expected.to allow_value("#abc").for(:bg_color_hex) }
      it { is_expected.to allow_value("#abc").for(:text_color_hex) }
      it { is_expected.not_to allow_value("3.0").for(:company_size) }
      it { is_expected.to allow_value("3").for(:company_size) }

      it { is_expected.to allow_value("1345abc").for(:slug) }
      it { is_expected.to allow_value("just_non_digit_characters").for(:slug) }
      it { is_expected.to allow_value("123_4").for(:slug) }
      it { is_expected.not_to allow_value("1234").for(:slug) }
    end
  end

  context "when callbacks are triggered before save" do
    it "generates a secret if set to empty string" do
      organization.secret = ""
      organization.save
      expect(organization.reload.secret).not_to eq("")
    end

    it "generates a secret if set to nil" do
      organization.secret = nil
      organization.save
      expect(organization.reload.secret).not_to be_nil
    end
  end

  describe "#name" do
    it "rejects names with over 50 characters" do
      organization.name = "x" * 51
      expect(organization).not_to be_valid
    end

    it "accepts names with 50 or less characters" do
      organization.name = "x" * 50
      expect(organization).to be_valid
    end
  end

  describe "#summary" do
    it "rejects summaries with over 250 characters" do
      organization.summary = "x" * 251
      expect(organization).not_to be_valid
    end

    it "accepts summaries with 250 or less characters" do
      organization.summary = "x" * 250
      expect(organization).to be_valid
    end
  end

  describe "#text_color_hex" do
    it "accepts hex color codes" do
      organization.text_color_hex = Faker::Color.hex_color
      expect(organization).to be_valid
    end

    it "rejects color names" do
      organization.text_color_hex = Faker::Color.color_name
      expect(organization).not_to be_valid
    end

    it "rejects RGB colors" do
      organization.text_color_hex = Faker::Color.rgb_color
      expect(organization).not_to be_valid
    end

    it "rejects wrong color format" do
      organization.text_color_hex = "#FOOBAR"
      expect(organization).not_to be_valid
    end
  end

  describe "#slug" do
    it "accepts properly formatted slug" do
      organization.slug = "heyho"
      expect(organization).to be_valid
    end

    it "accepts properly formatted slug with numbers" do
      organization.slug = "HeyHo2"
      expect(organization).to be_valid
    end

    it "rejects slug with spaces" do
      organization.slug = "hey ho"
      expect(organization).not_to be_valid
    end

    it "rejects slug with unacceptable character" do
      organization.slug = "Hey&Ho"
      expect(organization).not_to be_valid
    end

    it "downcases slug" do
      organization.slug = "HaHaHa"
      organization.save
      expect(organization.slug).to eq("hahaha")
    end

    it "rejects reserved slug" do
      organization = build(:organization, slug: "settings")
      expect(organization).not_to be_valid
      expect(organization.errors[:slug].to_s.include?("reserved")).to be true
    end

    it "takes organization slug into account" do
      create(:user, username: "lightalloy")
      organization = build(:organization, slug: "lightalloy")
      expect(organization).not_to be_valid
      expect(organization.errors[:slug].to_s.include?("taken")).to be true
    end

    it "takes podcast slug into account" do
      create(:podcast, slug: "devpodcast")
      organization = build(:organization, slug: "devpodcast")
      expect(organization).not_to be_valid
      expect(organization.errors[:slug].to_s.include?("taken")).to be true
    end

    it "takes page slug into account" do
      create(:page, slug: "needed_info_for_site")
      organization = build(:organization, slug: "needed_info_for_site")
      expect(organization).not_to be_valid
      expect(organization.errors[:slug].to_s.include?("taken")).to be true
    end

    it "takes sitemap into account" do
      organization = build(:organization, slug: "sitemap-yo")
      expect(organization).not_to be_valid
      expect(organization.errors[:slug].to_s.include?("taken")).to be true
    end

    context "when callbacks are triggered after save" do
      let(:organization) { build(:organization) }

      before do
        allow(Organizations::BustCacheWorker).to receive(:perform_async)
      end

      it "triggers cache busting on save" do
        organization.save
        expect(Organizations::BustCacheWorker).to have_received(:perform_async).with(organization.id, organization.slug)
      end
    end
  end

  describe "#url" do
    it "accepts valid http url" do
      organization.url = "http://ben.com"
      expect(organization).to be_valid
    end

    it "accepts valid secure http url" do
      organization.url = "https://ben.com"
      expect(organization).to be_valid
    end

    it "rejects invalid http url" do
      organization.url = "ben.com"
      expect(organization).not_to be_valid
    end
  end

  describe "#check_for_slug_change" do
    let(:user) { create(:user) }

    it "properly updates the slug/username" do
      random_new_slug = "slug_#{rand(10_000)}"
      organization.update(slug: random_new_slug)
      expect(organization.slug).to eq(random_new_slug)
    end

    it "updates old_slug to original slug if slug was changed" do
      original_slug = organization.slug
      organization.update(slug: "slug_#{rand(10_000)}")
      expect(organization.old_slug).to eq(original_slug)
    end

    it "updates old_old_slug properly if slug was changed and there was an old_slug" do
      original_slug = organization.slug
      organization.update(slug: "something_else")
      organization.update(slug: "another_slug")
      expect(organization.old_old_slug).to eq(original_slug)
    end

    context "when dealing with organization articles" do
      before do
        create(:organization_membership, user: user, organization: organization, type_of_user: "admin")
        article = create(:article, organization: organization, user: user)
        organization.articles << article
        organization.save
      end

      it "updates the paths of the organization's articles" do
        new_slug = "slug_#{rand(10_000)}"

        sidekiq_perform_enqueued_jobs(only: Organizations::UpdateOrganizationArticlesPathsWorker) do
          organization.update(slug: new_slug)
        end

        article = Article.find_by(organization_id: organization.id)
        expect(article.path).to include(new_slug)
      end

      it "updates article's cached_organization profile image", :aggregate_failures do
        # What is going on with this spec? Follow the comments.
        #
        # tl;dr - verifying fix for https://github.com/forem/forem/issues/17041

        # Create an organization and article, verify the article has cached the initial profile
        # image of the organization.
        original_org = create(:organization, profile_image: Rails.root.join("app/assets/images/1.png").open)
        article = create(:article, organization: original_org)
        expect(article.cached_organization.profile_image_url).to eq(original_org.profile_image_url)

        # For good measure let's have two of these articles
        create(:article, organization: original_org)

        # A foible of CarrierWave is that I can't re-upload for the same model in memory.  I need to
        # refind the record.  #reload does not work either.  (I lost sleep on this portion of the
        # test)
        organization = described_class.find(original_org.id)

        # Verify that the organization's image changes.  See the above CarrierWave foible
        expect do
          organization.profile_image = File.open(Rails.root.join("app/assets/images/2.png"))
          organization.save!
        end.to change { organization.reload.profile_image_url }

        sidekiq_perform_enqueued_jobs

        # I want to collect reloaded versions of the organization's articles so I can see their
        # cached organization profile image
        articles_profile_image_urls = organization.articles
          .map { |art| art.reload.cached_organization.profile_image_url }.uniq

        # Because of the change `{ organization.reload... }` the organization's profile_image_url is
        # the most recent change.
        expect(articles_profile_image_urls).to eq([organization.profile_image_url])
      end

      it "updates article cached_organizations" do
        new_slug = "slug_#{rand(10_000)}"

        sidekiq_perform_enqueued_jobs(only: Organizations::UpdateOrganizationArticlesPathsWorker) do
          organization.update(slug: new_slug)
        end

        article = Article.find_by(organization_id: organization.id)
        expect(article.cached_organization.slug).to eq(new_slug)
      end

      # these tests rely on `Organization.update_articles_cached_organization` callback,
      # which will eventually invoke the trigger
      # rubocop:disable RSpec/NestedGroups
      context "when callbacks eventually invoke the trigger on Article.reading_list_document" do
        it "updates the articles .reading_list_document when updating the name" do
          article = Article.find_by(organization_id: organization.id)
          old_reading_list_document = article.reading_list_document

          organization.update(name: "ACME Org")

          sidekiq_perform_enqueued_jobs

          expect(article.reload.reading_list_document).not_to eq(old_reading_list_document)
        end

        it "does not update the articles .reading_list_document when updating the company_size" do
          article = Article.find_by(organization_id: organization.id)
          old_reading_list_document = article.reading_list_document

          organization.update(company_size: "200")

          expect(article.reload.reading_list_document).to eq(old_reading_list_document)
        end
      end
      # rubocop:enable RSpec/NestedGroups
    end
  end

  describe "#enough_credits?" do
    it "returns false if the user has less unspent credits than neeed" do
      expect(organization.enough_credits?(1)).to be(false)
    end

    it "returns true if the user has the exact amount of unspent credits" do
      create(:credit, organization: organization, spent: false)
      expect(organization.enough_credits?(1)).to be(true)
    end

    it "returns true if the user has more unspent credits than needed" do
      create_list(:credit, 2, organization: organization, spent: false)
      expect(organization.enough_credits?(1)).to be(true)
    end
  end

  describe "#public_articles_count" do
    it "returns the count of published articles" do
      published_articles = create_list(:article, 2, organization: organization, published: true)
      create_list(:article, 1, organization: organization, published: false)

      expect(organization.public_articles_count).to eq(published_articles.count)
    end

    it "returns 0 if there are no published articles" do
      create_list(:article, 2, organization: organization, published: false)

      expect(organization.public_articles_count).to eq(0)
    end
  end

  describe ".simple_name_match" do
    before do
      create(:organization, name: "Not Matching")
      create(:organization, name: "For Fans of Books")
      create(:organization, name: "Boo! A Ghost")
    end

    it "finds them by simple ilike match" do
      query = "boo"
      results = described_class.simple_name_match(query)
      expect(results.pluck(:name)).to eq(["Boo! A Ghost", "For Fans of Books"])

      query = "book"
      results = described_class.simple_name_match(query)
      expect(results.pluck(:name)).to eq(["For Fans of Books"])

      query = "  BOOK  "
      results = described_class.simple_name_match(query)
      expect(results.pluck(:name)).to eq(["For Fans of Books"])
    end

    it "returns all orgs on empty query" do
      query = nil
      results = described_class.simple_name_match(query)
      expect(results.size).to eq(3)

      query = ""
      results = described_class.simple_name_match(query)
      expect(results.size).to eq(3)

      query = "        "
      results = described_class.simple_name_match(query)
      expect(results.size).to eq(3)
    end
  end

  describe "#generate_social_images" do
    before do
      allow(Images::SocialImageWorker).to receive(:perform_async)
      create(:article, organization: organization)
    end

    context "when the name or profile_image has changed and the organization has articles" do
      it "calls SocialImageWorker.perform_async" do
        organization.name = "New name for this org!"
        organization.save
        expect(Images::SocialImageWorker).to have_received(:perform_async)
      end
    end

    context "when the name or profile_image has not changed or the organization has no articles" do
      it "does not call SocialImageWorker.perform_async" do
        expect(Images::SocialImageWorker).not_to have_received(:perform_async)
        organization.save
      end
    end

    context "when the name or profile_image has changed and the organization has no articles" do
      it "does not call SocialImageWorker.perform_async" do
        organization.articles.destroy_all
        organization.name = "New name for this org!!"
        organization.save
        expect(Images::SocialImageWorker).not_to have_received(:perform_async)
      end
    end
  end

  describe "#bust_cache" do
    context "when a new user is added to the organization" do
      let(:user) { create(:user) }

      it "calls BustCachePathWorker after creating an organization membership" do
        org_membership = OrganizationMembership.create(user: user, organization: organization, type_of_user: "admin")

        allow(org_membership).to receive(:bust_cache)
        org_membership.save
        expect(org_membership).to have_received(:bust_cache)
      end
    end
  end

  context "when indexing with Algolia", :algolia do
    it "indexes the organization on create" do
      search_index_worker = AlgoliaSearch::SearchIndexWorker
      allow(search_index_worker).to receive(:perform_async)
      create(:organization)
      expect(search_index_worker).to have_received(:perform_async).with("Organization", kind_of(Integer), false).once
    end
  end
end
