# GGV Energy — solar consumption dashboard

Take-home for VREY. Imports energy load-profile data from a mock measurement API and shows, per house and per consumer, how much of their consumption was covered by the building's shared solar system (a "GGV" — *gemeinschaftliche Gebäudeversorgung*, the German shared-building-supply model).

**Stack:** Rails 8.1, PostgreSQL, Hotwire (Turbo + Stimulus), Tailwind, Solid Queue/Cache/Cable, RSpec.

## Getting started

```
bundle install
bin/rails db:prepare   # creates the dev database, loads the schema
bin/rails db:seed      # 2 houses, 5 consumers, plausible market/metering ids
bin/dev                # rails server + tailwind watcher
```

Open `localhost:3000`, pick a house, hit **Import data from API**. That queues a background job (Solid Queue, runs inline in dev via the `:async` adapter) that pulls both locations for every consumer in the house and rebuilds the solar numbers. The page updates itself over a Turbo Stream while it runs.

```
bundle exec rspec                           # 63 examples
bin/rubocop app config db spec lib          # style
bin/brakeman                                # static security scan
bin/bundler-audit check --update            # known-CVE gem scan
```

All clean as of this commit.

## Reviewing this

Each step from the assignment is its own tagged commit, so you can check out any point and get a working app at that stage:

| Tag | What it adds |
| --- | --- |
| `step-1-base-app` | Base app: import + display, nothing else |
| `task-consumer-daily` | Per-consumer daily breakdown page |
| `task-user-improvement` | Solar coverage % + CSV export |
| `task-performance` | Bounded import batches (the aggregate table itself was there from the start, see below) |
| `task-deploy-prep` | Production config, logging, error tracking |

`git tag -l` for the full list, `git diff step-1-base-app task-consumer-daily` to see any one step in isolation.

## Data model

```
House
  └─ has_many Consumer                      # a metered unit inside the house (apartment, heat pump...)
       └─ has_many Location                 # exactly one "market" + one "metering" location
            └─ has_many Reading             # one row per 15-minute interval from the API
       └─ has_many ConsumerDailyAggregate   # precomputed per-day rollup, see Performance
Import                                      # one row per import run, so status/errors show in the UI
```

`Location` holds the two ids the assignment specifies — a market location ("Marktlokation") id, validated as 10 digits, and a metering location ("Messlokation") id, validated as 33 characters. I gave it its own table instead of two columns on `Consumer` because a `Reading` belongs to one location, and it turns "does this consumer have both locations set up yet" (`Consumer#ready_for_import?`) into a real query instead of nil-checks scattered around.

Nothing else got modelled — no users, auth, tariffs, billing. The brief says not to model beyond what the features need, so I didn't.

## Assumptions

**What "the difference of the two locations" means.** I treat metering as the consumer's actual physical draw and market as what gets settled through the grid, so `solar = metering − market`. I take the absolute value per interval rather than trusting the sign, because the mock API returns independent random numbers for whatever location id you ask it for — the two series aren't actually related the way real metering data would be, so the sign is noise here. In a real system a negative `metering − market` would be worth alerting on, not silently flipping.

**The mock API doesn't echo back the location id you sent it.** The sample response shows `"locationId": ":location_id"`, literally unsubstituted, and the live mock API does the same. So `MeasurementApi::Client` never reads `locationId` from the response — the import job already knows which location it asked for and tags the readings itself. Easy thing to miss.

**Average daily solar consumption** = total solar ÷ number of distinct calendar days covered (a consumer's own days for its average, the house's union of dates across consumers for the house average).

**Data quality.** Every interval has a `quality` flag (always `"TRUE"` in the sample data, but it's there for a reason) — anything else gets excluded from sums. A day where the two locations don't agree on which intervals were reported gets flagged `complete: false` and shown as "Partial data" in the UI instead of quietly averaged away.

**Timeframe** shown in the UI comes from the earliest/latest reading actually in the database, not the date typed into the import form, so it stays honest if an import partially fails.

## What's built

- **Base app** — house list → house page with import form, live status via Turbo Streams, per-consumer and house-level total/average solar consumption and covered timeframe. The house list sorts by solar coverage, worst first, instead of alphabetically — for someone managing several GGV houses, "which buildings need attention" is more useful than an arbitrary order (one query across all houses, not one per house). Import also refuses to start a second run while one's in flight for that house.
- **Managing houses/consumers** — houses and consumers were originally seed/console-only; there are now forms for creating, editing, and deleting both, with a confirm dialog since deletes cascade (a house takes its consumers, locations, readings, and imports with it). Creating a consumer sets up both its market and metering location in the same submit, since it's not really usable for import until both exist. Location errors are attached with the role spelled out ("Market location ID must be exactly 10 digits") rather than a generic attribute error, since two location fields are on screen at once. There's deliberately no multi-tenant concept yet — the day that's real, this also needs actual auth and per-client scoping (right now anyone who can reach the app sees every house), and I'd rather call that out than bolt it on quietly.
- **Consumer daily view** (bonus) — click a consumer for a dedicated page with a small dependency-free SVG bar chart plus the exact numbers in a table. No JS charting library; at the volumes this deals with (tens to low hundreds of points) an `<svg>` with `<title>` tooltips does the job.
- **Solar coverage %** (bonus) — self-consumed solar ÷ total metered consumption, at house and consumer level. A raw kWh number doesn't mean much to a resident; "38% of your electricity came from the building's solar" does. Also added CSV export of a consumer's daily rollup for reporting.
- **Performance and deploy prep** (bonus) — see below.

## Performance

The real scaling problem here isn't the web layer, it's the data: every consumer generates 96 rows/day/location, so a 20-consumer building over a year is `20 × 2 × 365 × 96 ≈ 1.4M` rows — for one building. Two things follow:

1. **Don't recompute from raw readings on every page view.** House and consumer pages never sum over `readings` — they read from `ConsumerDailyAggregate`, a per-consumer-per-day rollup that `Solar::DailyAggregator` maintains during import, not on read. This was there from the first commit since it shapes `House`/`Consumer` from the start. For the building above, a house page goes from scanning ~2.8M rows to ~7,300, regardless of how many 15-minute intervals happened along the way.
2. **Don't build one unbounded SQL statement per import.** The first version of `ImportHouseJob` handed the API's entire interval list to a single `Reading.upsert_all` — fine for a 30-day demo, wrong for a first backfill of a year. It now writes in batches of 1,000 (`ImportHouseJob::UPSERT_BATCH_SIZE`), well under Postgres's bind-parameter limit no matter how far back `beginDate` goes.

Next in line if this kept growing: make `Solar::DailyAggregator` only recompute the range actually touched by an import instead of always walking `begin_date..Date.current`; split Solid Queue off the web dyno (`job` role in `config/deploy.yml` is already there, commented out) once imports stop being an occasional button click; paginate the houses list and cache each dashboard partial keyed on `ConsumerDailyAggregate#updated_at` if the list gets long (Solid Cache is configured, just unused right now).

## Deploy plan

Not actually deployed — no server/domain/registry to point at from here — but here's the concrete plan, sized for a company at VREY's stage (a handful of engineers, one product):

- **Where**: a single small VPS (Hetzner CX22 / DigitalOcean, ~€5–12/mo) running Postgres alongside the app to start, moving to a managed Postgres add-on once backups/HA matter more than the extra cost. `config/deploy.yml` and the Dockerfile are the `rails new` defaults, used as-is. `SOLID_QUEUE_IN_PUMA: true` runs jobs inside the web process rather than standing up a worker fleet for what's currently an occasional button click — the commented-out `job` role in `deploy.yml` is there for when that's no longer true. Kamal's proxy handles TLS and zero-downtime deploys; `assume_ssl`/`force_ssl` are already on in production config to match.
- **Logging**: Rails logs to STDOUT in production already (what Kamal expects); `lograge` collapses that to one line per request. For anything beyond `bin/kamal app logs`, ship STDOUT to a hosted log drain rather than standing up ELK.
- **Monitoring**: `/up` wired to a free uptime monitor with Slack/email alerts. Error tracking is `sentry-ruby`/`sentry-rails`, already in the Gemfile and initialized — inert until `SENTRY_DSN` is set as a Kamal secret.
- **Backups**: whatever the Postgres provider gives out of the box, or `pg_dump` on a cron if self-hosting. Not implemented, but the first thing I'd set up before this touches real customer data.

## What I'd do with more time

- **Recurring imports** instead of a manual button — Solid Queue's recurring jobs are already configured (`config/recurring.yml`), just unused — fetching only the delta since the last successful import.
- **Retry just the failed consumers** on a partial import instead of re-running the whole house.
- **System tests.** The suite covers models, services, jobs, and requests, but no Capybara test drives the actual import-and-watch-it-update flow through a real browser — the one thing request specs can't verify (that the Turbo Stream broadcast actually reaches the page).
- **Multi-tenant + real auth.** Right now this is a single-tenant admin tool, no login at all. Adding a `Client` above `House` is a cheap data-model change; the real work is accounts, sessions, and scoping every query to what the logged-in user can see. That's its own piece of work, not something to fold into the CRUD forms task.
- **A tenant-facing view.** "Each consumer can check their own consumption" implies a second, narrower user role that only sees their own apartment — built on top of the auth above, plus a real answer for how a tenant's login gets linked to their `Consumer` record (self-signup vs. invite).
- I'd also want to sit down with whoever owns the GGV/MaLo/MeLo domain knowledge and check the solar-difference assumption above against how the real metering setup actually works, rather than go on my own reading of the assignment text.
