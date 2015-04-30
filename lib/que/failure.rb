require 'que'
require 'que/failure/sql'
require 'que/failure/version'

require 'que/failure/strategies/no_retry'
require 'que/failure/strategies/variable_retry'

module Que
  module Failure
    class << self
      def on_unhandled_failure(&callback)
        @unhandled_failure_callback = callback
      end

      def unhandled_failure(error, job)
        return unless @unhandled_failure_callback

        @unhandled_failure_callback.call(error, job)
      rescue
      end
    end
  end
end
