require 'spec_helper'
require 'shared_behaviour'

describe "no retry strategy" do
  before do
    Que::Failure.on_unhandled_failure do |error, job|
      $global_failure = true
    end
  end

  before { $global_failure = nil }

  describe "when the job fails" do
    class NoRetryJob < Que::Job
      include Que::Failure::NoRetry

      def run
        raise StandardError.new('I broke.')
      end
    end

    it_behaves_like "marks the job as failed and non-retryable", NoRetryJob
    it_behaves_like "calls the global failure handler", NoRetryJob
  end

  context "when the job raises an exception that doesn't inherit from StandardError" do
    class ApocalypticException < Exception; end

    class CatastrophicJob < Que::Job
      include Que::Failure::NoRetry

      def run
        raise ApocalypticException.new("I don't inherit from StandardError")
      end
    end

    it "is still marked as non-retryable in the database" do
      CatastrophicJob.enqueue
      job = DB[:que_jobs].first
      job[:retryable].should == true

      begin
        Que::Job.work
      rescue ApocalypticException
      end

      job = DB[:que_jobs].first
      job[:error_count].should == 0
      job[:retryable].should == false
    end
  end
end

