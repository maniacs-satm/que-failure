require 'spec_helper'
require 'shared_behaviour'

describe "variable retry strategy" do
  before do
    Que::Failure.on_unhandled_failure do |error, job|
      $global_failure = true
    end
  end

  before do
    $global_failure = nil
    $final_retry_callback = nil
  end

  describe "when there are no retryable exceptions" do
    class JobA < Que::Job
      include Que::Failure::VariableRetry

      def run
        raise StandardError.new('I broke.')
      end
    end

    it_behaves_like "marks the job as failed and non-retryable", JobA
    it_behaves_like "calls the global failure handler", JobA
  end

  describe "when there are retryable exceptions" do
    describe "when no retry intervals have been set" do
      class MyError < StandardError; end

      class JobB < Que::Job
        include Que::Failure::VariableRetry

        retryable_exceptions [StandardError]

        def run
          raise MyError.new('I broke.')
        end
      end

      it_behaves_like "marks the job as failed and non-retryable", JobB
      it_behaves_like "calls the global failure handler", JobB
    end

    describe "when an un-retryable exception is raised" do
      class JobC < Que::Job
        include Que::Failure::VariableRetry

        retryable_exceptions [RuntimeError]

        def run
          raise StandardError.new('I broke.')
        end
      end

      it_behaves_like "marks the job as failed and non-retryable", JobC
      it_behaves_like "calls the global failure handler", JobC
    end

    describe "with pre-determined retry intervals set" do
      class JobD < Que::Job
        include Que::Failure::VariableRetry

        retryable_exceptions [StandardError]
        retry_intervals [1000]

        def run
          raise StandardError.new('I broke.')
        end
      end

      before do
        Que::Failure.on_retryable_failure do |error, job|
          $hiccup = true
        end
      end

      it_behaves_like "marks the job as retryable", JobD

      it "calls the retryable_failure callback" do
        JobD.enqueue :priority => 89
        Que::Job.work
        $hiccup.should == true
      end
    end

    describe "with callable retry intervals set" do
      class JobD2 < Que::Job
        include Que::Failure::VariableRetry

        retryable_exceptions [StandardError]
        retry_intervals [-> { (30..90).to_a.sample }]

        def run
          raise StandardError.new('I broke.')
        end
      end

      before do
        Que::Failure.on_retryable_failure do |error, job|
          $hiccup = true
        end
      end

      it_behaves_like "marks the job as retryable", JobD2
    end

    describe "with all retry intervals exhausted" do
      describe "when the job is not marked for deletion after final retry" do
        class JobE < Que::Job
          include Que::Failure::VariableRetry

          retryable_exceptions [StandardError]
          retry_intervals []

          after_final_retry do |error, job|
            $final_retry_callback = true
          end

          def run
            raise StandardError.new('I broke.')
          end
        end

        it_behaves_like "marks the job as failed and non-retryable", JobE
        it_behaves_like "calls the global failure handler", JobE

        it "calls the after_final_retry callback" do
          JobE.enqueue :priority => 89
          Que::Job.work
          $final_retry_callback.should == true
        end
      end

      describe "when the job is marked for deletion after final retry" do
        class JobF < Que::Job
          include Que::Failure::VariableRetry

          retryable_exceptions [StandardError]
          retry_intervals []

          destroy_after_final_retry!

          after_final_retry do |_, _|
            $final_retry_callback = true
          end

          def run
            raise StandardError.new('I broke.')
          end
        end

        it "destroys the job" do
          JobF.enqueue :priority => 89
          Que::Job.work
          job = DB[:que_jobs].first
          job.should == nil
        end

        it "calls the after_final_retry handler" do
          JobF.enqueue :priority => 89
          Que::Job.work
          $final_retry_callback.should == true
        end
      end
    end
  end

  describe "when an exception is raised in the after_final_retry callback" do
    class JobG < Que::Job
      include Que::Failure::VariableRetry

      retryable_exceptions [StandardError]
      retry_intervals []

      after_final_retry do |_, _|
        raise StandardError.new('Full breakage')
      end

      def run
        raise StandardError.new('I broke.')
      end
    end

    it_behaves_like "marks the job as failed and non-retryable", JobG
    it_behaves_like "calls the global failure handler", JobG
  end
end
