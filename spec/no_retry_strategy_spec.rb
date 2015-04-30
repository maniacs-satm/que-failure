require 'spec_helper'

describe "no retry strategy" do
  it "fails the job" do
    class NoRetryJob < Que::Job
      include Que::Failure::NoRetry

      def run
        raise StandardError.new('I broke.')
      end
    end

    NoRetryJob.enqueue
    job = DB[:que_jobs].first
    job[:retryable].should == true
    Que::Job.work
    job = DB[:que_jobs].first
    job[:error_count].should == 1
    job[:retryable].should == false
  end

  it "marks jobs as unretryable in the event of an apocalyspe" do
    class ApocalypticException < Exception; end

    class CatastrophicJob < Que::Job
      include Que::Failure::NoRetry

      def run
        raise ApocalypticException.new('brrrraaains')
      end
    end

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

  describe "when a catastrophic failure arises" do
    it "will call the on_unhandled_failure callback" do
      class CatastrophicJob < Que::Job
        include Que::Failure::NoRetry

        def run
          raise Error.new('brrrraaains')
        end
      end

      Que::Failure.on_unhandled_failure do |_, _|
        $catastrophy = true
      end

      CatastrophicJob.enqueue
      job = DB[:que_jobs].first
      job[:retryable].should == true

      begin
        Que::Job.work
      rescue StandardError
      end

      job = DB[:que_jobs].first
      job[:error_count].should == 1
      job[:retryable].should == false
      $catastrophy.should == true
    end
  end
end

