module Users
  class ResaveArticlesWorker
    include Sidekiq::Job

    sidekiq_options queue: :medium_priority, retry: 10, lock: :until_executing

    def perform(user_id)
      user = User.find_by(id: user_id)
      return unless user

      user.articles.find_each(&:save)
    end
  end
end
