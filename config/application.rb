require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module GgvApp
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # The measurement API reports everything in Europe/Berlin local time
    # (interval timestamps come back with a +01:00/+02:00 offset); matching
    # the app's zone to it means dates shown in the UI line up with the
    # date range someone actually typed into the import form, instead of
    # silently drifting by a day around UTC midnight.
    config.time_zone = "Berlin"

    # config.eager_load_paths << Rails.root.join("extras")

    # Generators (`rails g model ...`) should produce RSpec specs, not
    # Minitest tests.
    config.generators do |g|
      g.test_framework :rspec, fixtures: false
    end
  end
end
