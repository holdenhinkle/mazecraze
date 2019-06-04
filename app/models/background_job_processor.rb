class BackgroundJobProcessor
  attr_reader :jobs, :number_of_threads
  attr_accessor :threads

  @processors = []

  class << self
    attr_accessor :processors
  end

  def initialize(number_of_threads = 3)
    self.class.processors << self
    @number_of_threads = number_of_threads
    @threads = []
    @jobs = Queue.new
    enqueue_jobs
    run
  end

  def self.active_processor
    processors.each do |processor|
      processor.threads.each do |thread|
        return processor if thread.alive? && processor.queue_open?
      end
    end
    nil
  end

  def still_active?
    threads.each do |thread|
      return true if thread.alive? && queue_open?
    end
    false
  end

  def enqueue_jobs
    BackgroundJob.all_jobs_of_status_type('queued').each do |job|
      enqueue_job(job)
    end
  end

  def enqueue_job(job)
    jobs << { id: job['id'],
              type: job['job_type'],
              params: JSON.parse(job['params']) }
  end

  def queue_open?
    !jobs.closed?
  end

  private

  def run
    number_of_threads.times do
      threads << Thread.new do
        while queue_open? || jobs?
          job = wait_for_job
          BackgroundJob.new(job).run if job
        end
      end
      stop unless queue_open? || jobs?
    end
  end

  def jobs?
    !jobs.empty?
  end

  def wait_for_job
    jobs.pop(false)
  end

  def stop
    jobs.close
    threads.each(&:join).each(&:exit).clear
    self.class.processors.delete(self)
    true
  end
end
