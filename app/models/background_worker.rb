module MazeCraze
  class BackgroundWorker
    extend MazeCraze::Queryable
    include MazeCraze::Queryable

    MIN_THREADS = 1
    MAX_THREADS = 10

    @worker = nil

    class << self
      attr_accessor :worker
    end

    def self.alive?
      return false if worker.nil?
      !worker.dead?
    end

    def self.number_of_threads
      sql = 'SELECT integer_value FROM settings WHERE name = $1;'
      query(sql, 'number_of_threads').first['integer_value'].to_i
    end

    def self.update_number_of_threads(number)
      sql = 'UPDATE settings SET integer_value = $1, updated = $2 WHERE name = $3;'
      query(sql, number, 'NOW()', 'number_of_threads')
    end

    def self.start
      BackgroundWorker.new
    end

    def self.stop
      MazeCraze::BackgroundThread.kill_all_threads
      MazeCraze::BackgroundJob.undo_running_jobs
      MazeCraze::BackgroundJob.update_queue_order_upon_stop
      MazeCraze::BackgroundJob.reset_running_jobs
      kill_worker if worker
    end

    def self.kill_worker
      worker.kill_worker
    end

    attr_reader :job_queue
    attr_accessor :id, :number_of_threads, :threads, :deleted_jobs_to_skip

    def initialize
      self.class.worker = self
      @number_of_threads = self.class.number_of_threads
      @threads = []
      @deleted_jobs_to_skip = []
      @job_queue = Queue.new
      save!
      enqueue_jobs
      work
    end

    def enqueue_jobs
      return if MazeCraze::BackgroundJob.all.empty?

      queued = MazeCraze::BackgroundJob.all.select { |job| job.status == 'queued' }

      sorted = queued.sort_by do |job|
        job.queue_order
      end

      sorted.each do |job|
        enqueue_job(job) if job.status == 'queued'
      end
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
      threads << thread = Thread.new do
        if thread.nil?
          threads.delete(nil) # does this do anything?
          next
        end
        background_thread = MazeCraze::BackgroundThread.new(id, thread)

        while job_queue_open?
          background_thread.mode = Thread.current[:mode] = 'waiting'
          background_thread.background_job_id = nil
          job = wait_for_job

          if job && deleted_jobs_to_skip.include?(job.id)
            deleted_jobs_to_skip.delete(job.id)
            next
          elsif job
            background_thread.mode = Thread.current[:mode] = 'processing'
            background_thread.background_job_id = job.id
            job.update_job_is_running(background_thread.id)
            MazeCraze::BackgroundJob.queue_count -= 1
            MazeCraze::BackgroundJob.decrement_queued_jobs_queue_order
            job.run
          end
        end
      end

      delete_stopped_threads_from_threads
    end

    def skip_job_in_queue(job_id)
      deleted_jobs_to_skip << job_id
    end

    def cancel_job(thread_id, job_id)
      binding.pry if MazeCraze::BackgroundThread.all.count != threads.count

      background_thread = MazeCraze::BackgroundThread.thread_from_id(thread_id)
      threads.delete(MazeCraze::BackgroundThread.all.delete(background_thread).kill_thread)

      binding.pry if MazeCraze::BackgroundThread.all.count != threads.count

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
      return false if threads.any?(&:alive?) && job_queue_open?
      true
    end

    private

    def delete_stopped_threads_from_threads
      threads.select(&:nil?).each { |thread| threads.delete(thread) }
    end

    def save!
      sql = "INSERT INTO background_workers DEFAULT VALUES RETURNING id;"
      self.id = query(sql).first['id']
    end

    def update_worker_status(status)
      sql = "UPDATE background_workers SET status = $1, updated = $2 WHERE id = $3;"
      query(sql, status, 'NOW()', id)
    end

    def work
      number_of_threads.times { new_thread }
    end

    def jobs_in_job_queue?
      !job_queue.empty?
    end

    def wait_for_job
      job_queue.pop(false)
    end
  end
end
