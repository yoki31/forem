require "rails_helper"
require "swagger_helper"

# rubocop:disable RSpec/EmptyExampleGroup
# rubocop:disable RSpec/VariableName
# rubocop:disable Layout/LineLength

RSpec.describe "Api::V1::Docs::Articles" do
  let(:organization) { create(:organization) } # not used by every spec but lower times overall
  let(:tag) { create(:tag, :with_colors, name: "discuss") }
  let(:published_article) { create(:article, featured: true, tags: "discuss", published: true) }
  let(:unpublished_aricle) { create(:article, published: false) }
  let(:api_secret) { create(:api_secret) }
  let(:user) { api_secret.user }
  let(:user_article) { create(:article, featured: true, tags: "discuss", published: true, user_id: user.id) }
  let(:Accept) { "application/vnd.forem.api-v1+json" }

  before { stub_const("FlareTag::FLARE_TAG_IDS_HASH", { "discuss" => tag.id }) }

  describe "GET /articles" do
    before do
      published_article.update_columns(organization_id: organization.id)
    end

    path "/api/articles" do
      post "Publish article" do
        tags "articles"
        description "This endpoint allows the client to create a new article.

\"Articles\" are all the posts that users create on DEV that typically show up in the feed. They can be a blog post, a discussion question, a help thread etc. but is referred to as article within the code."
        operationId "createArticle"
        produces "application/json"
        consumes "application/json"
        parameter name: :article,
                  in: :body,
                  description: "Representation of Article to be created",
                  schema: { "$ref": "#/components/schemas/Article" }

        response "201", "An Article" do
          let(:"api-key") { api_secret.secret }
          let(:article) do
            {
              article: {
                title: "New article",
                body_markdown: "**New** body for the article",
                published: true,
                series: "custom series",
                main_image: "https://res.cloudinary.com/practicaldev/image/fetch/s--Jbk_rL1D--/c_imagga_scale,f_auto,fl_progressive,h_420,q_auto,w_1000/https://thepracticaldev.s3.amazonaws.com/i/5wfo25724gzgk5e5j50g.jpg",
                canonical_url: "https://dev.to/fdocr/headless-chrome-dual-mode-tests-for-ruby-on-rails-4p6g",
                description: "New post example",
                tags: "ruby selenium capybara rspec",
                organization_id: organization.id
              }
            }
          end
          add_examples

          run_test!
        end

        response "401", "Unauthorized" do
          let(:"api-key") { nil }
          let(:id) { published_article.id }
          let(:article) { { article: {} } }
          add_examples

          run_test!
        end

        response "422", "Unprocessable Entity" do
          let(:"api-key") { api_secret.secret }
          let(:id) { user_article.id }
          let(:article) { { article: {} } }
          add_examples

          run_test!
        end
      end

      get "Published articles" do
        security []
        tags "articles"
        description "This endpoint allows the client to retrieve a list of articles.

\"Articles\" are all the posts that users create on DEV that typically
show up in the feed. They can be a blog post, a discussion question,
a help thread etc. but is referred to as article within the code.

By default it will return featured, published articles ordered
by descending popularity.

It supports pagination, each page will contain `30` articles by default."
        operationId "getArticles"
        produces "application/json"
        parameter "$ref": "#/components/parameters/pageParam"
        parameter "$ref": "#/components/parameters/perPageParam30to1000"
        parameter name: :tag, in: :query, required: false,
                  description: "Using this parameter will retrieve articles that contain the requested tag. Articles
will be ordered by descending popularity.This parameter can be used in conjuction with `top`.",
                  schema: { type: :string },
                  example: "discuss"
        parameter name: :tags, in: :query, required: false,
                  description: "Using this parameter will retrieve articles with any of the comma-separated tags.
Articles will be ordered by descending popularity.",
                  schema: { type: :string },
                  example: "javascript, css"
        parameter name: :tags_exclude, in: :query, required: false,
                  description: "Using this parameter will retrieve articles that do _not_ contain _any_
of comma-separated tags. Articles will be ordered by descending popularity.",
                  schema: { type: :string },
                  example: "node, java"
        parameter name: :username, in: :query, required: false,
                  description: "Using this parameter will retrieve articles belonging
            to a User or Organization ordered by descending publication date.
            If `state=all` the number of items returned will be `1000` instead of the default `30`.
            This parameter can be used in conjuction with `state`.",
                  schema: { type: :string },
                  example: "ben"
        parameter name: :state, in: :query, required: false,
                  description: "Using this parameter will allow the client to check which articles are fresh or rising.
            If `state=fresh` the server will return fresh articles.
            If `state=rising` the server will return rising articles.
            This param can be used in conjuction with `username`, only if set to `all`.",
                  schema: {
                    type: :string,
                    enum: %i[fresh rising all]
                  },
                  example: "fresh"
        parameter name: :top, in: :query, required: false,
                  description: "Using this parameter will allow the client to return the most popular articles
in the last `N` days.
`top` indicates the number of days since publication of the articles returned.
This param can be used in conjuction with `tag`.",
                  schema: {
                    type: :integer,
                    format: :int32,
                    minimum: 1
                  },
                  example: 2
        parameter name: :collection_id, in: :query, required: false,
                  description: "Adding this will allow the client to return the list of articles
belonging to the requested collection, ordered by ascending publication date.",
                  schema: {
                    type: :integer,
                    format: :int32
                  },
                  example: 99

        response "200", "A List of Articles" do
          let(:"api-key") { nil }
          schema  type: :array,
                  items: { "$ref": "#/components/schemas/ArticleIndex" }
          add_examples

          run_test!
        end
      end
    end
  end

  describe "/api/articles/latest" do
    before { create_list(:article, 3) }

    path "/api/articles/latest" do
      get "Published articles sorted by published date" do
        security []
        tags "articles"
        description "This endpoint allows the client to retrieve a list of articles. ordered by descending publish date.

It supports pagination, each page will contain 30 articles by default."
        operationId "getLatestArticles"
        produces "application/json"

        parameter "$ref": "#/components/parameters/pageParam"
        parameter "$ref": "#/components/parameters/perPageParam30to1000"

        response "200", "A List of Articles" do
          schema  type: :array,
                  items: { "$ref": "#/components/schemas/ArticleIndex" }
          add_examples

          run_test!
        end
      end
    end
  end

  describe "/api/articles/{id}" do
    path "/api/articles/{id}" do
      get "Published article by id" do
        security []
        tags "articles"
        description "This endpoint allows the client to retrieve a single published article given its `id`."
        operationId "getArticleById"
        produces "application/json"
        parameter name: :id, in: :path, type: :integer, required: true

        response "200", "An Article" do
          let(:id) { published_article.id }
          schema  type: :object,
                  items: { "$ref": "#/components/schemas/ArticleIndex" }
          add_examples

          run_test!
        end

        response "404", "Article Not Found" do
          let(:id) { 1_234_567_890 }
          add_examples

          run_test!
        end
      end

      put "Update an article by id" do
        tags "articles"
        description "This endpoint allows the client to update an existing article.

\"Articles\" are all the posts that users create on DEV that typically show up in the feed. They can be a blog post, a discussion question, a help thread etc. but is referred to as article within the code."
        operationId "updateArticle"
        produces "application/json"
        consumes "application/json"
        parameter name: :id,
                  in: :path,
                  required: true,
                  description: "The ID of the user to unpublish.",
                  schema: {
                    type: :integer,
                    format: :int32,
                    minimum: 1
                  },
                  example: 123
        parameter name: :article,
                  in: :body,
                  description: "Representation of Article to be updated",
                  schema: { "$ref": "#/components/schemas/Article" }

        response "200", "An Article" do
          let(:"api-key") { api_secret.secret }
          let(:id) { user_article.id }
          let(:article) { { article: { body_markdown: "**New** body for the article" } } }
          add_examples

          run_test!
        end

        response "404", "Article Not Found" do
          let(:"api-key") { api_secret.secret }
          let(:id) { 1_234_567_890 }
          let(:article) { { article: {} } }
          add_examples

          run_test!
        end

        response "401", "Unauthorized" do
          let(:"api-key") { nil }
          let(:id) { published_article.id }
          let(:article) { { article: {} } }
          add_examples

          run_test!
        end

        response "422", "Unprocessable Entity" do
          let(:"api-key") { api_secret.secret }
          let(:id) { user_article.id }
          let(:article) { { article: {} } }
          add_examples

          run_test!
        end
      end
    end
  end

  path "/api/articles/{username}/{slug}" do
    get "Published article by path" do
      security []
      tags "articles"
      description "This endpoint allows the client to retrieve a single published article given its `path`."
      operationId "getArticleByPath"
      produces "application/json"
      parameter name: :username, in: :path, type: :string, required: true
      parameter name: :slug, in: :path, type: :string, required: true

      response "200", "An Article" do
        let(:username) { published_article.username }
        let(:slug) { published_article.slug }
        schema  type: :object,
                items: { "$ref": "#/components/schemas/ArticleIndex" }
        add_examples

        run_test!
      end

      response "404", "Article Not Found" do
        let(:username) { "invalid" }
        let(:slug) { "invalid" }
        add_examples

        run_test!
      end
    end
  end

  describe "GET /articles/me" do
    path "/api/articles/me" do
      get "User's articles" do
        tags "articles", "users"
        description "This endpoint allows the client to retrieve a list of published articles on behalf of an authenticated user.

\"Articles\" are all the posts that users create on DEV that typically show up in the feed. They can be a blog post, a discussion question, a help thread etc. but is referred to as article within the code.

Published articles will be in reverse chronological publication order.

It will return published articles with pagination. By default a page will contain 30 articles."
        operationId "getUserArticles"
        produces "application/json"
        parameter "$ref": "#/components/parameters/pageParam"
        parameter "$ref": "#/components/parameters/perPageParam30to1000"

        response "401", "Unauthorized" do
          let(:"api-key") { nil }
          add_examples

          run_test!
        end

        response "200", "A List of the authenticated user's Articles" do
          let(:"api-key") { api_secret.secret }
          schema  type: :array,
                  items: { "$ref": "#/components/schemas/ArticleIndex" }
          add_examples

          run_test!
        end
      end
    end

    path "/api/articles/me/published" do
      get "User's published articles" do
        tags "articles", "users"
        description "This endpoint allows the client to retrieve a list of published articles on behalf of an authenticated user.

\"Articles\" are all the posts that users create on DEV that typically show up in the feed. They can be a blog post, a discussion question, a help thread etc. but is referred to as article within the code.

Published articles will be in reverse chronological publication order.

It will return published articles with pagination. By default a page will contain 30 articles."
        operationId "getUserPublishedArticles"
        produces "application/json"
        parameter "$ref": "#/components/parameters/pageParam"
        parameter "$ref": "#/components/parameters/perPageParam30to1000"

        response "401", "Unauthorized" do
          let(:"api-key") { nil }
          add_examples

          run_test!
        end

        response "200", "A List of the authenticated user's Articles" do
          let(:"api-key") { api_secret.secret }
          schema  type: :array,
                  items: { "$ref": "#/components/schemas/ArticleIndex" }
          add_examples

          run_test!
        end
      end
    end

    path "/api/articles/me/unpublished" do
      get "User's unpublished articles" do
        tags "articles", "users"
        description "This endpoint allows the client to retrieve a list of unpublished articles on behalf of an authenticated user.

\"Articles\" are all the posts that users create on DEV that typically show up in the feed. They can be a blog post, a discussion question, a help thread etc. but is referred to as article within the code.

Unpublished articles will be in reverse chronological creation order.

It will return unpublished articles with pagination. By default a page will contain 30 articles."
        operationId "getUserUnpublishedArticles"
        produces "application/json"
        parameter "$ref": "#/components/parameters/pageParam"
        parameter "$ref": "#/components/parameters/perPageParam30to1000"

        response "401", "Unauthorized" do
          let(:"api-key") { nil }
          add_examples

          run_test!
        end

        response "200", "A List of the authenticated user's Articles" do
          let(:"api-key") { api_secret.secret }
          schema  type: :array,
                  items: { "$ref": "#/components/schemas/ArticleIndex" }
          add_examples

          run_test!
        end
      end
    end

    path "/api/articles/me/all" do
      get "User's all articles" do
        tags "articles", "users"
        description "This endpoint allows the client to retrieve a list of all articles on behalf of an authenticated user.

\"Articles\" are all the posts that users create on DEV that typically show up in the feed. They can be a blog post, a discussion question, a help thread etc. but is referred to as article within the code.

It will return both published and unpublished articles with pagination.

Unpublished articles will be at the top of the list in reverse chronological creation order. Published articles will follow in reverse chronological publication order.

By default a page will contain 30 articles."
        operationId "getUserAllArticles"
        produces "application/json"
        parameter "$ref": "#/components/parameters/pageParam"
        parameter "$ref": "#/components/parameters/perPageParam30to1000"

        response "401", "Unauthorized" do
          let(:"api-key") { nil }
          add_examples

          run_test!
        end

        response "200", "A List of the authenticated user's Articles" do
          let(:"api-key") { api_secret.secret }
          schema  type: :array,
                  items: { "$ref": "#/components/schemas/ArticleIndex" }
          add_examples

          run_test!
        end
      end
    end
  end

  describe "PUT /articles/:id/unpublish" do
    before do
      user.add_role(:admin)
    end

    path "/api/articles/{id}/unpublish" do
      put "Unpublish an article" do
        tags "articles"
        description "This endpoint allows the client to unpublish an article.

The user associated with the API key must have any 'admin' or 'moderator' role.

The article will be unpublished and will no longer be visible to the public. It will remain
in the database and will set back to draft status on the author's posts dashboard. Any
notifications associated with the article will be deleted. Any comments on the article
will remain."
        operationId "unpublishArticle"
        produces "application/json"
        parameter name: :id, in: :path, required: true,
                  description: "The ID of the article to unpublish.",
                  schema: {
                    type: :integer,
                    format: :int32,
                    minimum: 1
                  },
                  example: 1

        parameter name: :note, in: :query, required: false,
                  description: "Content for the note that's created along with unpublishing",
                  schema: { type: :string },
                  example: "Admin requested unpublishing all articles via API"

        response "204", "Article successfully unpublished" do
          let(:"api-key") { api_secret.secret }
          let(:id) { published_article.id }
          add_examples

          run_test!
        end

        response "401", "Article already unpublished" do
          let(:"api-key") { api_secret.secret }
          let(:id) { unpublished_aricle.id }
          add_examples

          run_test!
        end

        response "401", "Unauthorized" do
          let(:regular_user) { create(:user) }
          let(:low_security_api_secret) { create(:api_secret, user: regular_user) }
          let(:"api-key") { low_security_api_secret.secret }
          let(:id) { unpublished_aricle.id }
          add_examples

          run_test!
        end

        response "404", "Article Not Found" do
          let(:"api-key") { api_secret.secret }
          let(:id) { 0 }
          add_examples

          run_test!
        end
      end
    end
  end
  # rubocop:enable RSpec/VariableName
  # rubocop:enable RSpec/EmptyExampleGroup
  # rubocop:enable Layout/LineLength
end
