module Que
  module Failure
    # NoRetry does not retry the job at all. This is the same default behaviour as Resque.
    module NoRetry
      def self.included(base)
        base.extend(ClassMethods)
      end

      def _run()
        Que.execute :set_job_retryable, [false] + attrs.values_at(:queue, :priority, :run_at, :job_id)
        super
      end

      module ClassMethods
        def handle_job_failure(error, job)
          begin
            count    = job[:error_count].to_i + 1
            message  = "#{error.message}\n#{error.backtrace.join("\n")}"

            Que.execute :fail_job, [count, message] + job.values_at(:queue, :priority, :run_at, :job_id)
          ensure
            Que::Failure.unhandled_failure(error, job)
          end
        end
      end
    end
  end
end
