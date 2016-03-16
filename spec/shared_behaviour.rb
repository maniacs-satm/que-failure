require 'spec_helper'

shared_examples "marks the job as failed and non-retryable" do |job_class|
  it "increments the error count" do
    job_class.enqueue :priority => 89
    Que::Job.work
    job = DB[:que_jobs].first
    job[:error_count].should == 1
  end

  it "marks the job as non-retryable" do
    job_class.enqueue :priority => 89
    Que::Job.work
    job = DB[:que_jobs].first
    job[:retryable].should == false
  end

  it "sets a failed_at on the job" do
    job_class.enqueue :priority => 89
    Que::Job.work
    job = DB[:que_jobs].first
    t = (Time.now ).to_f.round(6)
    job[:failed_at].to_f.round(6).should be_within(1.5).of(t + 1.0)
  end
end

shared_examples "marks the job as retryable" do |job_class|
  it "increments the error count" do
    job_class.enqueue :priority => 89
    Que::Job.work
    job = DB[:que_jobs].first
    job[:error_count].should == 1
  end

  it "marks the job as retryable" do
    job_class.enqueue :priority => 89
    Que::Job.work
    job = DB[:que_jobs].first
    job[:retryable].should == true
  end

  it "doesn't set a failed_at on the job" do
    job_class.enqueue :priority => 89
    Que::Job.work
    job = DB[:que_jobs].first
    job[:failed_at].should == nil
  end
end

shared_examples "calls the global failure handler" do |job_class|
  it "calls the global failure handler" do
    job_class.enqueue :priority => 89
    Que::Job.work
    $global_failure.should == true
  end
end
