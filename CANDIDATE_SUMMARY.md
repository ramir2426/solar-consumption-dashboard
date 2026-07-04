# Candidate summary

*Draft — please read this over and make it sound like you before sending it.
It's written in first person as a starting point, not a final answer; the
parts most worth double-checking are marked below.*

## How I perceived this challenge

I liked that it was deliberately underspecified in a few places — the
exact meaning of "the difference of the two locations," how much of the
optional list to attempt, what "a valuable user-facing feature" even
means for this domain. That's a more honest test of how I work than a
fully-specified ticket would be: it forced me to actually figure out
what a market/metering location pair represents in a GGV setup before I
could write a line of the aggregation logic, and to make a couple of
calls I'd normally check with a teammate or a domain owner rather than
guess at silently.

The two decisions I spent the most time on:

1. What "solar consumption = difference of the two locations" should
   do when the two numbers don't behave the way real metering data
   would (this mock API hands back independent random values per
   location, so the sign of `metering - market` isn't meaningful the
   way it would be against real readings). I went with the absolute
   value and wrote down why in the README rather than picking silently.
2. How much of the optional list to take on in the time I had. I chose
   depth on a couple of things (the consumer daily page, a solar
   coverage % that I think is a genuinely more useful number than a raw
   kWh total, the performance path for the aggregation table) over
   trying to touch all four superficially.

## How I approached it

- Read the data through by hand first (the sample response you gave,
  and then the live mock API) before writing any model code, since the
  `locationId` field in the sample being a literal, unsubstituted
  `":location_id"` placeholder was the kind of detail that's easy to
  miss and then get bitten by later.
- Built the base app as a real, working iteration first — imports,
  stores, displays, has tests — and tagged it, before touching any of
  the optional tasks, so there'd be an honest checkpoint of "this is
  exactly what was asked for" to look at separately from anything
  extra.
- Treated the performance question as a design decision from the start
  rather than an afterthought bolted on at the end: the house/consumer
  pages read from a precomputed daily rollup table, not from summing
  raw 15-minute readings, from the very first commit that has a UI at
  all.
- Kept the scope of "nice to have" additions deliberately narrow rather
  than trying to gold-plate everything — I'd rather hand over a few
  things done well and clearly explained than a longer list of
  half-finished ones.

## What I'd want to talk through in the interview

- The GGV/market-location/metering-location assumption above — whether
  my reading of which side of the subtraction is which matches how
  it actually works for VREY.
- Where I drew the line on scope, and whether that matches what you'd
  want to see from someone in this role.
- The performance tradeoffs section in the README, and what actually
  breaks first at VREY's real scale versus what I guessed at.

*[If you used AI tooling (mention what, and how much) — add that note
here, however much detail you're comfortable sharing. The assignment
explicitly says this is fine and that they'd welcome seeing the
prompts/log if you want to share them.]*
