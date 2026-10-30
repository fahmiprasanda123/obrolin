# MongoDB has no transactional rollback here, and Redis keys persist, so
# both are wiped between examples.
RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner[:mongoid].clean_with(:deletion)
    # The $text search needs the text index to exist.
    Mongoid::Tasks::Database.create_indexes
  end

  config.before do
    DatabaseCleaner[:mongoid].strategy = :deletion
    DatabaseCleaner[:mongoid].start
    REDIS.with(&:flushdb)
    Rails.cache.clear
  end

  config.after do
    DatabaseCleaner[:mongoid].clean
  end
end
