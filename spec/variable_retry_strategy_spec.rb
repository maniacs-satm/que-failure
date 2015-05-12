require 'spec_helper'

describe "variable retry strategy" do
  describe "when there are no retryable exceptions" do
    it "fails the job and calls the on_unhandled_failure callback" do

      class JobA < Que::Job
        include Que::Failure::VariableRetry

        def run
          raise StandardError.new('I broke.')
        end
      end

      Que::Failure.on_unhandled_failure do |error, job|
        $job = job
        $error = error
      end

      JobA.enqueue :priority => 89
      Que::Job.work
      job = DB[:que_jobs].first
      job[:error_count].should == 1
      job[:retryable].should == false
      t = (Time.now ).to_f.round(6)
      job[:failed_at].to_f.round(6).should be_within(1.5).of(t + 1.0)
      $error.class.should == StandardError
      $job[:job_id].should == job[:job_id]
    end
  end

  describe "when there are retryable exceptions" do
    describe "when an un-retryable exception is raised" do
      it "will fail a job" do
        class JobB < Que::Job
          include Que::Failure::VariableRetry

          retryable_exceptions [RuntimeError]

          def run
            raise StandardError.new('I broke.')
          end
        end

        JobB.enqueue :priority => 89
        Que::Job.work
        job = DB[:que_jobs].first
        job[:error_count].should == 1
        job[:retryable].should == false
        t = (Time.now ).to_f.round(6)
        job[:failed_at].to_f.round(6).should be_within(1.5).of(t + 1.0)
      end
    end

    describe "with no retry intervals have been set" do
      it "fails the job" do
        class MyError < StandardError; end

        class JobC < Que::Job
          include Que::Failure::VariableRetry

          retryable_exceptions [StandardError]

          def run
            raise MyError.new('I broke.')
          end
        end

        JobC.enqueue :priority => 89
        Que::Job.work
        job = DB[:que_jobs].first
        job[:error_count].should == 1
        job[:retryable].should == false
        t = (Time.now ).to_f.round(6)
        job[:failed_at].to_f.round(6).should be_within(1.5).of(t + 1.0)
      end
    end

    describe "with retry intervals set" do
      it "errors the job" do
        class JobD < Que::Job
          include Que::Failure::VariableRetry

          retryable_exceptions [StandardError]
          retry_intervals [1000]

          def run
            raise StandardError.new('I broke.')
          end
        end

        JobD.enqueue :priority => 89
        Que::Job.work
        job = DB[:que_jobs].first
        job[:error_count].should == 1
        job[:retryable].should == true
        job[:failed_at].should == nil
      end
    end

    describe "with all retry intervals exhausted" do
      describe "when the job is not marked for deletion after final retry" do
        it "fails the job, calls the after_final_retry and global failure handler" do

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

          Que::Failure.on_unhandled_failure do |error, job|
            $catastrophy = true
          end

          JobE.enqueue :priority => 89
          Que::Job.work
          job = DB[:que_jobs].first
          job[:error_count].should == 1
          job[:retryable].should == false
          t = (Time.now ).to_f.round(6)
          job[:failed_at].to_f.round(6).should be_within(1.5).of(t + 1.0)
          $final_retry_callback.should == true
          $catastrophy.should == true
        end
      end

      describe "when the job is marked for deletion after final retry" do
        it "destroys the job and calls after final retry handler" do

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

          JobF.enqueue :priority => 89
          Que::Job.work
          job = DB[:que_jobs].first
          job.should.should == nil
          $final_retry_callback.should == true
        end
      end
    end
  end

  describe "when an exception is raised in the after_final_retry callback" do
    it "will call the on_unhandled_failure callback" do
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

      Que::Failure.on_unhandled_failure do |error, job|
        $catastrophy = true
      end

      JobG.enqueue :priority => 89
      Que::Job.work
      job = DB[:que_jobs].first
      $catastrophy.should == true
    end
  end
end
