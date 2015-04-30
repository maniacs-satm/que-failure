module Que
  SQL[:fail_job] = %{
      UPDATE que_jobs
      SET failed_at = now(),
          error_count = $1::bigint,
          last_error = $2::text,
          retryable = false
      WHERE queue = $3::text
      AND priority = $4::smallint
      AND run_at = $5::timestamptz
      AND job_id = $6::bigint
  }.freeze

  SQL[:set_job_retryable] = %{
      UPDATE que_jobs
      SET retryable = $1::bool
      WHERE queue = $2::text
      AND priority = $3::smallint
      AND run_at = $4::timestamptz
      AND job_id = $5::bigint
  }.freeze
end
