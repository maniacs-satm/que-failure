module Que
  module Failure
    # VariableRetry will retry the job on each retry intervals, assuming failures are safe
    # to retry.
    module VariableRetry
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def retry_intervals(intervals)
          @retry_intervals = intervals
        end

        def retryable_exceptions(exceptions)
          @retryable_exceptions = exceptions
        end

        def after_final_retry(&callback)
          @after_final_retry_callback = callback
        end

        def destroy_after_final_retry!
          @destroy_after_final_retry = true
        end

        def handle_job_failure(error, job)
          count    = job[:error_count].to_i + 1
          message  = "#{error.message}\n#{error.backtrace.join("\n")}"

          if retryable_exception?(error)
            delay = @retry_intervals && @retry_intervals[count - 1]

            if delay
              Que.execute :set_error, [count, delay, message] + job.values_at(:queue, :priority, :run_at, :job_id)
              Que::Failure.retryable_failure(error, job)
            else
              @after_final_retry_callback.call(error, job) if @after_final_retry_callback

              if @destroy_after_final_retry
                Que.execute :destroy_job, job.values_at(:queue, :priority, :run_at, :job_id)
              else
                Que.execute :fail_job, [count, message] + job.values_at(:queue, :priority, :run_at, :job_id)
                Que::Failure.unhandled_failure(error, job)
              end
            end
          else
            Que.execute :fail_job, [count, message] + job.values_at(:queue, :priority, :run_at, :job_id)
            Que::Failure.unhandled_failure(error, job)
          end
        rescue => error
          Que::Failure.unhandled_failure(error, job)
        end

        private

        def retryable_exception?(error)
          return false unless @retryable_exceptions

          @retryable_exceptions.any? { |exception_class| error.is_a?(exception_class) }
        end
      end
    end
  end
end
