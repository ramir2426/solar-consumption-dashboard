# Error tracking. Deliberately a no-op in development/test and in any
# environment where SENTRY_DSN isn't set, so this never gets in the way
# locally or in this take-home's sandbox -- see the README's
# "Logging & monitoring" section for how this gets wired up for real.
if ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.breadcrumbs_logger = [ :active_support_logger ]
    config.environment = Rails.env
    # Trace a sample of requests rather than all of them; App Signal/Sentry
    # style APM is a nice-to-have here, not the primary purpose of this DSN.
    config.traces_sample_rate = 0.1
  end
end
