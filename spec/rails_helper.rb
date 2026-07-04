# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'
require 'webmock/rspec'
require 'capybara/rspec'
# Add additional requires below this line. Rails is not loaded until this point!

# The measurement API is a real external service; specs should never hit
# it (or any other network) by accident. Individual specs stub exactly
# the requests they expect with WebMock.
WebMock.disable_net_connect!

# This app builds its own object graphs per spec rather than relying on
# fixtures or FactoryBot -- House -> Consumer -> Location -> Reading has
# enough relational shape that plain factory methods read more clearly
# than either would. See spec/support/domain_factory.rb.
Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }

# Ensures that the test database schema matches the current schema file.
# If there are pending migrations it will invoke `db:test:prepare` to
# recreate the test database by loading the schema.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.use_transactional_fixtures = true

  # Lets spec/requests, spec/models, spec/jobs, etc. pick up the right
  # RSpec::Rails behaviour (request helpers, ActiveJob matchers, ...)
  # from where the file lives, instead of tagging every describe block
  # with `type: :request` by hand.
  config.infer_spec_type_from_file_location!

  config.include DomainFactory
  config.include ActiveJob::TestHelper

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
end
