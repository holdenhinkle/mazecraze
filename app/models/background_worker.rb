require 'singleton'

module MazeCraze
  class BackgroundWorker
    include Singleton
    include MazeCraze::Queryable

    @mutex = Mutex.new

    class << self
      attr_reader :mutex
    end

    attr_accessor :id, :deleted_jobs_to_skip_in_queue, :job_queue

    def initialize
      @id = save!
      start if MazeCraze::BackgroundJob.jobs_of_status_type('queued').any?
    end

    def start
      # housekeeping
      update_worker_status('alive')
      self.job_queue = Queue.new
      self.deleted_jobs_to_skip_in_queue = []
      enqueue_jobs
      work
      self
    end

    def stop
      MazeCraze::BackgroundThread.kill_all_threads
      MazeCraze::BackgroundJob.undo_running_jobs
      MazeCraze::BackgroundJob.update_queue_order_upon_stop
      MazeCraze::BackgroundJob.reset_running_jobs
      reset
      self
    end

    def restart
      stop.start
    end

    def enqueue_jobs
      queued_jobs = MazeCraze::BackgroundJob.jobs_of_status_type('queued')

      sorted_jobs = queued_jobs.each.sort_by { |job, _| job['queue_order'] }

      sorted_jobs.each { |job, _| enqueue_job(job['id'].to_i) }
    end

    def enqueue_job(job_id)
      job_queue << job_id
      sql = 'UPDATE background_jobs SET background_worker_id = $1, updated = $2 WHERE id = $3;'
      query(sql, id, 'NOW()', job_id)
    end

    def skip_job_in_queue(job_id)
      deleted_jobs_to_skip_in_queue << job_id
    end

    def dead?
      threads = BackgroundThread.all_background_thread_threads
      return false if threads.any?(&:alive?) && job_queue_open?
      true
    end

    def alive?
      !dead?
    end

    def new_thread
      thread_obj = MazeCraze::BackgroundThread.new(id)

      thread_obj.thread = Thread.new do
        next if thread_obj.thread.nil?

        while job_queue_open?
          thread_wait(thread_obj)
          job_id = wait_for_job

          if job_id && deleted_jobs_to_skip_in_queue.include?(job_id)
            deleted_jobs_to_skip_in_queue.delete(job_id)
            next
          elsif job_id
            job = MazeCraze::BackgroundJob.job_from_id(job_id)
            thread_process(thread_obj, job)
          end
        end
      end

      binding.pry if thread_obj.thread.nil?
    end

    private

    def housekeeping
      MazeCraze::BackgroundThread.sanitize_background_threads_table
      MazeCraze::BackgroundJob.sanitize_background_jobs_table
    end

    def thread_wait(thread_obj)
      thread_obj.mode = 'waiting'
      thread_obj.background_job_id = nil
    end

    def thread_process(thread_obj, job)
      thread_obj.mode = 'processing'
      thread_obj.background_job_id = job.id
      job.prepare_to_run(thread_obj)
    end

    def save!
      sql = "INSERT INTO background_workers DEFAULT VALUES RETURNING id;"
      query(sql).first['id'].to_i
    end

    def update_worker_status(status)
      sql = "UPDATE background_workers SET status = $1, updated = $2 WHERE id = $3;"
      query(sql, status, 'NOW()', id)
    end

    def work
      BackgroundThread.number_of_threads.times { new_thread }
    end

    def job_queue_open?
      !job_queue.closed?
    end

    def jobs_in_job_queue?
      !job_queue.empty?
    end

    def wait_for_job
      job_queue.pop(false)
    end

    def reset
      job_queue.close if job_queue
      update_worker_status('dead')
    end
  end
end
