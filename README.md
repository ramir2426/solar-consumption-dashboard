# GGV Energy — solar consumption dashboard

A Rails app that imports energy load-profile data from a mock measurement
API and shows, per house and per consumer, how much of their consumption
was covered by the building's shared solar system (a "GGV" —
*gemeinschaftliche Gebäudeversorgung*, the German shared-building-supply
model). Built as a take-home for VREY.

**Stack:** Ruby on Rails 8.1, PostgreSQL, Hotwire (Turbo + Stimulus),
Tailwind CSS, Solid Queue/Cache/Cable, RSpec.

## Getting started

```
bundle install
bin/rails db:prepare   # creates the dev database and loads the schema
bin/rails db:seed      # 2 houses, 5 consumers, plausible market/metering ids
bin/dev                # rails server + tailwind watcher
```

Open `http://localhost:3000`, pick a house, and click **Import data from
API**. That kicks off a background job (Solid Queue; runs inline via the
`:async` adapter in development, no extra process needed) that fetches
both locations for every consumer in the house and rebuilds the solar
numbers — the page updates itself over a Turbo Stream as it runs, no
reload needed.

```
bundle exec rspec                           # 47 examples
bin/rubocop app config db spec lib          # style (rubocop-rails-omakase)
bin/brakeman                                # static security scan
bin/bundler-audit check --update            # known-CVE gem scan
```

All four are clean as of this commit.

## How to review this

Each step from the assignment is its own tagged commit, in order, so you
can check out any point and get a working app at exactly that stage:

| Tag | What it adds |
| --- | --- |
| `step-1-base-app` | The required base app: import + display, nothing else |
| `task-consumer-daily` | Per-consumer daily breakdown page |
| `task-user-improvement` | Solar coverage % + CSV export |
| `task-performance` | Bounded import batches (aggregate table was there from the start — see below) |
| `task-deploy-prep` | Production config hardening, logging/error tracking |

`git log --oneline` / `git tag -l` to see them all; `git diff step-1-base-app task-consumer-daily` etc. to see any single step in isolation.

## The data model

```
House
  └─ has_many Consumer            # a metered unit inside the house (an apartment, a heat pump...)
       └─ has_many Location        # exactly one "market" + one "metering" location
            └─ has_many Reading    # one row per 15-minute interval from the API
       └─ has_many ConsumerDailyAggregate   # precomputed per-day rollup, see "Performance" below
Import                             # one row per import run, so status/errors are visible in the UI
```

- **Location** holds the two ids the assignment specifies: a market
  location ("Marktlokation") id is validated as exactly 10 digits, a
  metering location ("Messlokation") id as exactly 33 characters.
- I modelled `Location` as its own table rather than two columns on
  `Consumer` because a `Reading` naturally belongs to *one* location, and
  because it made "does this consumer have both locations configured
  yet?" (`Consumer#ready_for_import?`) a real query instead of a pile of
  nil-checks.
- Nothing else got modelled — no attempt at users/auth, tariffs, billing,
  etc. The assignment explicitly says not to model beyond what the
  features need, and I took that at face value.

## Assumptions I made (and would confirm with a domain owner in real life)

**What "the difference of the values of the two locations" means.**
I treat the metering location as the consumer's real physical draw and
the market location as what's actually settled through the grid, so in a
real GGV the gap between them is the energy that came from the shared
solar system instead of the grid: `solar = metering − market`. I take
the **absolute value** of that per-interval, rather than trusting the
sign, for a concrete reason: this mock API returns independent random
numbers for whichever location id you ask it for (see below), so the two
series have no real relationship to each other the way genuine metering
data would — trusting the sign here would just be trusting noise. In a
real system, a negative `metering − market` would be worth alerting on,
not silently flipping.

**The mock API doesn't reliably echo back the location id you asked
for.** The sample response in the assignment shows `"locationId":
":location_id"` — the literal placeholder, unsubstituted. I confirmed
this against the live mock API too. Because of that,
`MeasurementApi::Client` never reads `locationId` out of the response at
all; the caller (the import job) already knows which location it asked
for and tags the stored readings itself. This felt like the kind of
detail that's easy to skim past and then get subtly bitten by later.

**"Average daily solar consumption"** = total solar consumption ÷ number
of distinct calendar days covered, at whichever level you're looking at
(a consumer's own days for its average; the house's set of distinct
dates across all its consumers for the house average).

**Data quality.** The API tags every interval with a `quality` flag
(always `"TRUE"` in the sample data, but the field exists for a reason).
Anything not `"TRUE"` is excluded from every sum. A day where the two
locations don't fully agree on which intervals were reported is flagged
`complete: false` on `ConsumerDailyAggregate` and surfaced in the UI
("Partial data on some days" / amber bars in the chart) instead of being
averaged away silently.

**Timeframe** shown in the UI comes from the earliest/latest reading
actually in the database, not from the date the user typed into the
import form — so it stays honest even if an import partially failed.

## Feature tour

- **Base app**: house list → house page with an import form, live
  status (Turbo Streams), and per-consumer + house-level total solar
  consumption, average daily solar consumption, and covered timeframe.
  The house list itself is sorted by solar coverage, worst first, rather
  than alphabetically — for a company managing many GGV houses, "which
  buildings need attention" is a more useful default than an arbitrary
  list (one query across every house via `ConsumerDailyAggregate`, not
  one query per house). The import button also refuses to start a second
  run while one's already in flight for that house, rather than letting
  a double-click spin up duplicate API calls.
- **Managing houses and consumers**: houses and consumers were originally
  seed/console-only; there are now proper forms (`/houses/new`,
  `/houses/:id/edit`, `/houses/:id/consumers/new`), plus delete, each
  behind a confirm dialog since both cascade (deleting a house takes
  every consumer, location, reading, and import with it). Creating a
  consumer sets up its market *and* metering location in the same submit
  — `accepts_nested_attributes_for`, not a two-step flow — since a
  consumer isn't really usable for import until both exist anyway (see
  `Consumer#ready_for_import?`). Location validation errors are attached
  to `:base` with the role spelled out in the message ("Market location
  ID must be exactly 10 digits") rather than the default `:location_id`
  attribute — with a market *and* a metering field on screen at once,
  "location must be exactly 10 digits" on its own doesn't say which one
  it's about. There's deliberately no concept of multiple clients/
  tenants each owning their own houses yet: the moment that's real, this
  app also needs real authentication and per-client data scoping (right
  now anyone who can reach it sees every house), which is a deliberate
  next step rather than something to bolt on quietly as a side effect of
  a CRUD form.
- **Consumer's daily** (bonus): click a consumer's name for a dedicated
  page — a small dependency-free SVG bar chart of daily solar
  consumption plus the exact numbers in a table. No JS charting library;
  at the data volumes this app deals with (tens to low hundreds of
  points) a `<title>`-tooltipped `<svg>` does the job without a
  dependency.
- **User-facing improvement** (bonus): a **solar coverage %** — self-
  consumed solar ÷ total metered consumption — at both the house and
  consumer level. I picked this because a raw kWh number doesn't mean
  much to a resident; "38% of your electricity came from the building's
  solar" does. Also added CSV export of a consumer's daily rollup, since
  this kind of number usually needs to leave the app for reporting.
- **Performance** (bonus): see below.
- **Deploy to prod** (bonus): see below.

## Performance: what would actually break as this grows

The realistic scaling problem for an app like this isn't the web layer,
it's the data: every consumer generates 96 rows a day per location, so a
building with 20 consumers over a year is `20 × 2 × 365 × 96 ≈ 1.4M`
rows, and that's one building. Two things follow from that:

1. **Don't recompute from raw readings on every page view.** The house
   and consumer pages never run `SUM(value)` over `readings` — they read
   from `ConsumerDailyAggregate`, a per-consumer-per-day rollup that
   `Solar::DailyAggregator` maintains as part of the import job, not on
   read. This was in the design from the first commit rather than bolted
   on after, because it changes the shape of `House`/`Consumer` from the
   start. For the 20-consumer/1-year building above, a house page goes
   from scanning ~2.8M rows to ~7,300 (20 consumers × 365 days) —
   independent of how many 15-minute intervals happened along the way.
2. **Don't build one unbounded SQL statement per import.** The first
   version of `ImportHouseJob` handed every interval the API returned
   straight to a single `Reading.upsert_all`. Fine for a 30-day demo
   import (a few thousand rows); wrong for a first-time backfill of a
   year of history. It now writes in fixed batches of 1,000
   (`ImportHouseJob::UPSERT_BATCH_SIZE`), which keeps every statement
   comfortably under Postgres's bind-parameter ceiling no matter how far
   back `beginDate` goes.

What I'd reach for next, roughly in order, if this kept growing: move
`Solar::DailyAggregator` to only recompute the date range actually
touched by an import instead of always walking `begin_date..Date.current`
(cheap now, wasteful once re-imports of already-imported ranges become
common); split Solid Queue's worker off the web dyno (`job` role in
`config/deploy.yml` is already there, commented out) once import volume
stops being "click a button occasionally"; and if the houses list itself
gets long, paginate it and add fragment caching around each house's
dashboard partial keyed on its latest `ConsumerDailyAggregate#updated_at`
(Solid Cache is already configured, just not used for this yet).

## Deploy to prod

Not actually deployed — I don't have a server, domain, or container
registry to point at from this environment — but the app is deploy-ready
and this is the concrete plan, sized for a company at VREY's stage (a
handful of engineers, one product, no need for multi-region or
Kubernetes yet):

- **Where**: a single small VPS (Hetzner CX22 / DigitalOcean, ~€5–12/mo)
  running Postgres itself (either as a Kamal accessory container on the
  same box to start, or a managed Postgres add-on once backups/HA matter
  more than the extra cost). `config/deploy.yml` and the multi-stage
  `Dockerfile` were generated by `rails new` and are used as-is; the
  interesting bit is what's already wired into them:
  - `SOLID_QUEUE_IN_PUMA: true` runs job processing inside the web
    process rather than standing up a separate worker fleet for what is,
    at this stage, an occasional button click. `config/deploy.yml` has a
    commented-out `job` role ready for when that's no longer true.
  - Kamal's built-in proxy handles TLS via Let's Encrypt and zero-
    downtime deploys; `config.assume_ssl` / `config.force_ssl` are on in
    `config/environments/production.rb` to match.
- **Logging**: Rails already logs to STDOUT in production (the Docker
  convention Kamal expects); `lograge` is on, so it's one line per
  request instead of Rails' multi-line default, which is the difference
  between "greppable" and "not" once there's any real volume. For
  anything beyond `bin/kamal app logs`, ship STDOUT to a hosted log
  drain (Better Stack has the friendliest free tier for a team this
  size) rather than rolling a self-hosted ELK stack.
- **Monitoring**: `/up` (Rails' built-in health check) wired to a
  free-tier uptime monitor (Better Stack / UptimeRobot) hitting it every
  minute with Slack/email alerting. Error tracking is `sentry-ruby` +
  `sentry-rails`, already in the Gemfile and initialized in
  `config/initializers/sentry.rb` — genuinely inert everywhere `SENTRY_DSN`
  isn't set (including in this take-home), becomes real the moment a
  DSN is provided as a Kamal secret.
- **Backups**: whatever the Postgres provider offers out of the box
  (managed snapshots, or `pg_dump` on a cron if self-hosting on the
  accessory container) — not implemented here, but the first thing I'd
  set up before this touches anything resembling real customer data.

## What I'd do with more time

- **Recurring imports.** Right now importing is a manual button click.
  A real version would run `ImportHouseJob` on a schedule (Solid Queue's
  recurring jobs, already configured in `config/recurring.yml`, just
  unused) and only fetch the delta since the last successful import
  instead of re-walking the whole range every time.
- **Retrying a failed/partial import for just the consumers that
  failed**, instead of re-running the whole house.
- **System tests.** The suite is models + services + job + requests; I
  didn't add a Capybara system test driving the actual import-and-watch-
  it-update flow through a real browser, which is the one thing request
  tests genuinely can't verify (that the Turbo Stream broadcast actually
  reaches the page).
- **Multi-currency/unit awareness** if this ever needs to show anything
  besides kWh.
- **Multiple clients, each owning their own houses, plus real
  authentication.** Right now this is a single-tenant admin tool with no
  login at all. A `Client` above `House` (`Client has_many :houses`) is
  a cheap data-model change; the real work is everything that has to
  come with it once it's real — accounts, sessions, and scoping every
  query (starting with the houses index we just built) to "what this
  logged-in user is allowed to see." I'd treat that as its own deliberate
  piece of work, not something to fold into a CRUD-forms task.
- **A separate tenant-facing view.** "Each consumer can check their own
  consumption" implies a second user role entirely — a tenant who logs
  in and sees *only* their own apartment, never the other consumers in
  the same house the ops dashboard deliberately shows side by side. That
  wants its own narrower surface built on top of the auth above, plus a
  real answer for how a tenant's login gets linked to their `Consumer`
  record in the first place (self-signup vs. an invite from the property
  manager) — a product decision, not just a technical one.
- I'd also want an actual conversation with whoever owns the GGV/MaLo/
  Melo domain knowledge to check the solar-difference assumption above
  against how the real metering setup works, rather than my best
  reading of the assignment text.

## A note on AI

I used Claude Code as a pair-programming tool throughout this — planning
the data model, writing code, running the real test suite/linters/
security scanners against it, and iterating based on what actually
failed. [Add your own note here about how you'd like to describe this
for VREY, and how much of the log/prompts you're comfortable sharing.]
