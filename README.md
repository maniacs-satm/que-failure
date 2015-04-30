# Do not use this with chanks/que

This extension relies on changes that we have made in a custom branch of
 [Que](https://github.com/gocardless/que/tree/flexible-failure-handling), which is
 currently in a pull request as part of an ongoing discussion.  This warning will be
 removed if the changes are merged into the canonical Que repo.

# Que::Failure

Que::Failure introduces a `failed` state for Que jobs that will prohibit them from being
 automatically re-run.  Alongside this it provides some configurable retry strategies
 for increased flexibility when dealing with failures.

## Usage

There are currently two strategies available, one is `NoRetry` which leaves jobs in a
 their failed state.  The other is `VariableRetry` which accepts some rules rules about
 how many times a job should be retried, and what kind of failures are acceptable for
 retrying.  Through these two strategies, you can achieve at-most-once and at-least-once
 semantics.

### Que::Failure::NoRetry (at-most-once)

This strategy provides behaviour similar to that of
 [Resque](https://github.com/resque/resque).  Jobs that have failed will be left in the
 queue so that they can be manipulated or inspected later.

```ruby
class PlaceOrder < Que::Job
  extend Que::Failure::NoRetry

  def run
    # Some error occurs here.
  end
end
```

### Que::Failure::VariableRetry (at-least-once)

This strategy will retry a job at the provided `retry_intervals` assuming that the
 failure was caused by one of the `retryable_exceptions`.  If any other kind of exception
 is raised the job will be left in a failed state and the `on_unhandled_error` callback
 will be invoked.

```ruby
class ProcessWebhook < Que::Job
  extend Que::Failure::VariableRetry

  retryable_exceptions [Timeout::Error]
  retry_intervals [30.seconds, 1.minute, 2.minutes]

  def run
    # Some code that talks to an unreliable HTTP server.
  end
end
```

There may be scenarios where it is useful to carry out an action after the retries have
 been exhausted.  Custom behaviour can be achieved through the `after_final_retry`
 callback, which will be passed the error encountered and the job.

Once all retries have been exhausted, the job will be failed and the `on_unhandled_error`
 callback will be invoked.  It is possible to bypass this behaviour and simply destroy
 the job with `destroy_after_final_retry!`, which will do nothing other than destroy the
 job.

```ruby
class ProcessWebhook < Que::Job
  extend Que::Failure::VariableRetry

  retryable_exceptions [Timeout::Error]
  retry_intervals [1.hour, 1.day, 1.week]
  destroy_after_final_retry!

  after_final_retry do |error, job|
    MetricsTracker.record(error)
  end

  def run
    # Some code that talks to an unreliable HTTP server.
  end
end
```

### Setting the unhandled failure callback

As stated previously, this callback will be invoked whenever an unrecoverable failure
 occurs, or in the event that a retryable job fails and it is not marked for destruction.

```ruby
Que::Failure.on_unhandled_failure do |error, job|
  Raven.capture(error)
end
```

### Additional queries

For convenience there are some canned statements that Que provides, for example:

```ruby
Que.execute :set_error, [error_count, delay, ...]
```

These statements have been extended to include two more:

| Statement | Arguments | Description |
|:----------|:----------|:------------|
|`fail_job` | `error_count`, `last_error`, `job_id` | Marks a job as failed, storing details, and prohibiting it from being re-run automatically. |
|`set_job_retryable`| `retryable`, `queue`, `priority`, `run_at`, `job_id` | Sets the jobs `retryable` flag.  Setting this to `false` will prohibit a job from being re-run automatically even though it has not failed. |


## Contributing

1. Fork it ( https://github.com/gocardless/que-failure/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
