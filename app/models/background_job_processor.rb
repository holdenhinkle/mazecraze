class BackgroundJobProcessor
  attr_reader :jobs, :number_of_threads
  attr_accessor :threads

  def initialize(number_of_threads = 1)
    @jobs = Queue.new
    @number_of_threads = number_of_threads
    @threads = []
  end

  def self.running?
    Thread.list.each do |thread|
      thread = thread.to_s
      # return true if thread.include?('background_job_processor.rb') &&
      #                thread.include?('run')
      return true if thread.include?('background_job_processor.rb')
    end
    false
  end

  def jobs?
    !jobs.empty?
  end

  def running?
    !jobs.closed?
  end

  # def dequeue
  #   jobs.pop(true)
  # end

  def wait_for_job
    jobs.pop(false)
  end

  def enqueue
    BackgroundJob.all_jobs_of_status_type('queued').each do |job|
      jobs << { id: job['id'],
                type: job['job_type'],
                params: JSON.parse(job['params']) }
    end
  end

  def run
    number_of_threads.times do
      threads << Thread.new do
        while running? || jobs?
          job = wait_for_job
          BackgroundJob.new(job).run if job
          # log thread
          # add new jobs to queue
        end
      end
    end
  end
end
