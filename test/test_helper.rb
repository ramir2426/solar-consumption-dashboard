ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"
require_relative "support/domain_factory"

# The measurement API is a real external service; tests should never hit
# it (or any other network) by accident. Individual tests stub exactly the
# requests they expect with WebMock.
WebMock.disable_net_connect!

module ActiveSupport
  class TestCase
    include DomainFactory
    include ActiveJob::TestHelper

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # This app builds its own object graphs per test rather than relying on
    # fixtures -- House -> Consumer -> Location -> Reading has enough
    # relational shape that plain factory methods read more clearly than
    # YAML fixtures would.
  end
end
