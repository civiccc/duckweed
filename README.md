# Duckweed

<img src="https://github.com/causes/duckweed/raw/master/public/icon.png" />

Duckweed is a general-purpose metrics service that can be used to count things.

It consists of a simple Sinatra front-end and a Redis back-end. No
configuration is required to start tracking new events; just make an HTTP POST
request to a Duckweed instance with a new event name and Duckweed will start
tracking it. Metrics can be read back from Duckweed with simple HTTP requests.

Examples of things you can do with Duckweed:

* product metrics: gauge the success of your product by pinging Duckweed every
  time a user takes a particular action on your site
* health metrics: count important application events to get immediate feedback
  when something is broken
* A/B testing: use Duckweed to record the activity of experiment and control
  groups
* application and server monitoring: count periodic events using Duckweed and
  ask a health monitoring service like Nagios to check whether the event's
  frequency is above the desired minimum threshold

Duckweed was designed to be simple, reliable and performant. It's easy to
set-up, and easy to use. It's particularly optimized for providing immediate,
real-time feedback to help you be aware of what's going on right now in your
app. It's not really intended to be a historical archive of all activity on
your site reaching far back in time.

## Integration with third-party services

* Geckoboard: Duckweed knows how to export results in JSON format suitable for
  consumption by Geckboard (http://www.geckoboard.com/), which means you can
  easily get insight into Duckweed's metrics in the form of graphical charts
  and counters
* Pingdom: Duckweed can answer health probes from the Pingdom monitoring
  service (http://pingdom.com/) so that you can be alerted as soon as an
  important metric falls below some critical threshold
* Airbrake/Hoptoad: Duckweed can talk to the Airbrake error reporting and
  aggregaton service (http://airbrakeapp.com/), so you'll find out if anything
  ever goes wrong with Duckweed itself

## Data storage

Events are stored in buckets of minute, hour, and day granularity. As Duckweed
is all about getting insight into current application behavior,
minute-granularity data is kept for 2 days, hour-granularity data is kept for
about a month, and day-granularity data is kept for 5 years.

## Set-up

1. Clone Duckweed on a box that has Redis installed and running
2. Install its dependencies using `bundle install`
3. Fire up a Ruby console with `bundle exec irb -r lib/duckweed/token -r
   lib/duckweed`
4. Set-up an auth token with `Duckweed::Token.authorize 'secret_token', 'rw'`
5. Run Duckweed using your Rack-compatible server of choice (for example, using
   `rackup`)

(Note that you can set up a token with read/write access for internal use, and
set up different tokens with only read access that you can assign to external
services such as Geckoboard and Pingdom.)

## Interface

You interact with Duckweed over a simple HTTP-based API. This means that you
can post events to Duckweed with basically any language that provides a means
of making HTTP requests. You can read event metrics back using the same tools.
It is even possible to script access to Duckweed using the `curl` tool from the
command-line.

All requests require authentication via the `auth_token` query paramter in the
URL, or HTTP Basic Authentication.

### `POST /track/:event`

Notify Duckweed that an event has occurred. Optionally takes a `quantity`
parameter (to indicate that a batch job has caused `:event` to occur a number
of times) and a `timestamp` parameter (useful, for example, when you are
running your Duckweed POST requests from an asynchronous work queue, and you
want the event to be recorded as having taken place when the job was enqueued,
not when it finally ran).

### `GET /count/:event` and `GET /count/:event/:granularity/:quantity`

Ask Duckweed the number of times an event has occurred. Optionally takes
`quantity` (a number) and `granularity` ("minutes", "hours", "days") parameters
so that you can specify the period over which the count should be returned.
Defaults to the last hour with minute-granularity. Also takes an optional
`offset` parameter, which can be used to look further back in time, starting
with older buckets (defaults to 1).

### `GET /histogram/:event`

Returns a JSON object suitable for consumption by Geckoboard which shows the
count of the requested `:event` over time. Respects the usual `quantity`,
`granuarity` and `offset` parameters.

### `GET /accumulate/:event`

Similar to the "histogram" action, but aggregates counts as it moves from older
to newer buckets, showing the additive affect of events over time.

### `POST /multicount`

Like "count" but can be used to query the counts for a large number of events
at once rather than having to make multiple GET requests.

### `GET /check/:event`

Given a `threshold` parameter make sure the count of the specified `:event` is
above the threshold. Returns a "GOOD" or "BAD" string that can be detected by a
monitoring service such as Nagios or Pingdom. Also takes the usual parameters
of `quantity` and `granularity`.

## About Causes (http://www.causes.com/)

We built Duckweed to give us real-time insight into our product's performance
and get rapid feedback on things like application health and experiment
results.

If you'd like to work with us, check out http://www.causes.com/join_us and get
in touch with us at jobs@causes.com.
