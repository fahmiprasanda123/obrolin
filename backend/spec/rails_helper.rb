require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
# Use a dedicated Redis DB so specs never touch development keys.
# (Set before boot: dotenv does not override variables that already exist.)
ENV["REDIS_URL"] = ENV.fetch("REDIS_TEST_URL", "redis://localhost:6379/15")

require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"

Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  # PostgreSQL: each example runs in a transaction that is rolled back.
  config.use_transactional_fixtures = true
  config.filter_rails_from_backtrace!
  config.infer_spec_type_from_file_location!

  config.include FactoryBot::Syntax::Methods
  config.include ActiveSupport::Testing::TimeHelpers
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
