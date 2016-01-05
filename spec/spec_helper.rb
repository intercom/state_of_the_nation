$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "state_of_the_nation"
require "active_support/testing/time_helpers"
require "active_record"

require "shoulda-matchers"
require "database_cleaner"
require "matchers"


ActiveRecord::Base.establish_connection(ENV["DATABASE_URL"] || "sqlite3::memory:")

def day(n)
  Time.at(n.days).utc.round
end

RSpec.configure do |config|
  config.include ActiveSupport::Testing::TimeHelpers

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end
