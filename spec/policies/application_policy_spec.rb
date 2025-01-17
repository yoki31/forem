require "rails_helper"

RSpec.describe ApplicationPolicy do
  # rubocop:disable RSpec/DescribedClass
  #
  # [@jeremyf] Disabling this because I'm testing inner classes, and explicit "This is the class"
  #            seems like a legible approach.
  describe ApplicationPolicy::NotAuthorizedError do
    subject(:error) { ApplicationPolicy::NotAuthorizedError.new("Message") }

    it { is_expected.to be_a(Pundit::NotAuthorizedError) }
    it { is_expected.to be_a(ApplicationPolicy::NotAuthorizedError) }
  end

  describe ApplicationPolicy::UserSuspendedError do
    subject(:error) { ApplicationPolicy::UserSuspendedError.new("Message") }

    it { is_expected.to be_a(Pundit::NotAuthorizedError) }
    it { is_expected.to be_a(ApplicationPolicy::NotAuthorizedError) }
  end

  describe ApplicationPolicy::UserRequiredError do
    subject(:error) { ApplicationPolicy::UserRequiredError.new("Message") }

    it { is_expected.to be_a(Pundit::NotAuthorizedError) }
    it { is_expected.to be_a(ApplicationPolicy::NotAuthorizedError) }
  end
  # rubocop:enable RSpec/DescribedClass

  describe ".dom_classes_for" do
    [
      [Article, :create?, "js-policy-article-create"],
      [:Article, :create?, "js-policy-article-create"],
      # Note the underscore for WorkerBee
      [:WorkerBee, :create?, "js-policy-worker_bee-create"],
      [Article.new(id: 5), :create, "js-policy-article-5-create"],
      [Article.new, :create, "js-policy-article-new-create"],
      [
        Article.new,
        :create,
        "js-policy-article-new-create hidden",
        # This needs to be a proc and not a lambda; if it's a lambda, the context for evaluation is
        # wildly off.  (and you need to do `before { instance_exec(&before_proc) }`); This is the
        # way to make the `before` call below the least surprising.
        proc {
          allow(ArticlePolicy).to receive(:include_hidden_dom_class_for?).with(query: :create).and_return(true)
        },
      ],
    ].each do |record, query, expected, before_proc|
      context "when record=#{record.inspect} and query=#{query.inspect}#{' with hidden true' if before_proc}" do
        subject { described_class.dom_classes_for(record: record, query: query) }

        let(:record) { record }
        let(:query) { query }

        before(&before_proc) if before_proc

        it { is_expected.to eq(expected) }
      end
    end
  end

  describe "require_user_in_good_standing!" do
    subject(:method_call) { described_class.require_user_in_good_standing!(user: user) }

    context "when no user given" do
      let(:user) { nil }

      it { within_block_is_expected.to raise_error ApplicationPolicy::UserRequiredError }
    end

    context "when given a user who is not suspended" do
      let(:user) { User.new }

      it { is_expected.to be_truthy }
    end

    context "when given a user who suspended" do
      let(:user) { build(:user, :suspended) }

      it { within_block_is_expected.to raise_error ApplicationPolicy::UserSuspendedError }
    end
  end

  describe "require_user!" do
    subject(:method_call) { described_class.require_user!(user: user) }

    context "when no user given" do
      let(:user) { nil }

      it { within_block_is_expected.to raise_error ApplicationPolicy::UserRequiredError }
    end

    context "when given a user" do
      let(:user) { User.new }

      it { is_expected.to be_truthy }
    end
  end
end
