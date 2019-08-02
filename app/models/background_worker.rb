module MazeCraze
  class BackgroundWorker
    extend MazeCraze::Queryable
    include MazeCraze::Queryable

    @worker = nil

    class << self
      attr_accessor :worker

      def alive?
        return false if worker.nil?
        !worker.dead?
      end

      def start
        BackgroundWorker.new
      end

      def stop
        MazeCraze::BackgroundThread.kill_all_threads
        MazeCraze::BackgroundJob.undo_running_jobs
        MazeCraze::BackgroundJob.update_queue_order_upon_stop
        MazeCraze::BackgroundJob.reset_running_jobs
        kill_worker if worker
      end

      def kill_worker
        worker.kill_worker
      end
    end

    attr_reader :job_queue
    attr_accessor :id, :deleted_jobs_to_skip

    def initialize
      self.class.worker = self
      @deleted_jobs_to_skip = []
      @job_queue = Queue.new
      save!
      enqueue_jobs
      work
    end

    def enqueue_jobs
      queued_jobs = MazeCraze::BackgroundJob.all.select do |job|
        job.status == 'queued'
      end

      queued_jobs.sort_by(&:queue_order).each { |job| enqueue_job(job) }
    end

    def enqueue_job(job)
      job_queue << job
      sql = 'UPDATE background_jobs SET background_worker_id = $1, updated = $2 WHERE id = $3;'
      query(sql, id, 'NOW()', job.id)
    end

    def job_queue_open?
      !job_queue.closed?
    end

    def new_thread
      thread_obj = MazeCraze::BackgroundThread.new(id)

      thread_obj.thread = Thread.new do
        next if thread_obj.thread.nil?

        while job_queue_open?
          thread_obj.mode = 'waiting'
          thread_obj.background_job_id = nil
          job = wait_for_job

          if job && deleted_jobs_to_skip.include?(job.id)
            deleted_jobs_to_skip.delete(job.id)
            next
          elsif job
            thread_obj.mode = 'processing'
            thread_obj.background_job_id = job.id
            job.update_job_is_running(thread_obj.id)
            MazeCraze::BackgroundJob.queue_count -= 1
            MazeCraze::BackgroundJob.decrement_queued_jobs_queue_order
            job.run
          end
        end
      end
    end

    def skip_job_in_queue(job_id)
      deleted_jobs_to_skip << job_id
    end

    def cancel_job(thread_id, job_id)
      background_thread = MazeCraze::BackgroundThread.thread_from_id(thread_id)
      MazeCraze::BackgroundThread.all.delete(background_thread).kill_thread
      job = MazeCraze::BackgroundJob.job_from_id(job_id)
      job.queue_order = job.class.queue_count += 1
      job.update_queue_order
      job.reset
      job.undo
      enqueue_job(job)
      new_thread
    end

    def kill_worker
      job_queue.close
      update_worker_status('dead')
      self.class.worker = nil
    end

    def dead?
      threads = BackgroundThread.all_background_thread_threads
      return false if threads.any?(&:alive?) && job_queue_open?
      true
    end

    private

    def save!
      sql = "INSERT INTO background_workers DEFAULT VALUES RETURNING id;"
      self.id = query(sql).first['id']
    end

    def update_worker_status(status)
      sql = "UPDATE background_workers SET status = $1, updated = $2 WHERE id = $3;"
      query(sql, status, 'NOW()', id)
    end

    def work
      BackgroundThread.number_of_threads.times { new_thread }
    end

    def jobs_in_job_queue?
      !job_queue.empty?
    end

    def wait_for_job
      job_queue.pop(false)
    end
  end
end
