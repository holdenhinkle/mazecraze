module MazeCraze
  class BackgroundWorker
    extend MazeCraze::Queryable
    include MazeCraze::Queryable

    MIN_THREADS = 1
    MAX_THREADS = 10

    @all = []

    class << self
      attr_accessor :all
    end

    attr_reader :job_queue
    attr_accessor :id, :number_of_threads, :threads, :deleted_jobs

    def initialize
      self.class.all << self
      @id = nil
      @number_of_threads = self.class.number_of_threads
      @threads = []
      @deleted_jobs = []
      @job_queue = Queue.new
      save!
      enqueue_jobs
      work
    end

    def self.each_worker
      all.each { |worker| yield(worker) }
    end

    def self.active_workers
      active_workers = []
      each_worker do |worker|
        worker.threads.each do |thread|
          if thread.alive? && worker.job_queue_open?
            active_workers << worker
            break
          end
        end
      end
      active_workers
    end

    def self.worker_from_id(worker_id)
      each_worker { |worker| return worker if worker.id == worker_id }
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
      BackgroundThread.kill_all_threads
      BackgroundJob.undo_running_jobs
      BackgroundJob.reset_running_jobs
      BackgroundWorker.kill_all_workers
    end

    def enqueue_jobs
      BackgroundJob.each_job { |job| enqueue_job(job) if job.status == 'queued' }
    end

    def enqueue_job(job)
      job_queue << job
      sql = 'UPDATE background_jobs SET background_worker_id = $1, updated = $2 WHERE id = $3;'
      query(sql, id, 'NOW()', job.id)
    end

    def dead?
      return false if threads.any?(&:alive?) && job_queue_open?
      true
    end

    def job_queue_open?
      !job_queue.closed?
    end

    def delete_job(job_id)
      deleted_jobs << job_id
    end

    # REFACTOR THIS
    def kill_specific_job(thread_id, job_id)
      BackgroundThread.background_thread_from_id(thread_id).kill_thread

      job = BackgroundJob.job_from_id(job_id)
      job.reset
      job.undo
      enqueue_job(job)
      new_thread
    end

    def self.kill_all_workers
      each_worker(&:kill_worker)
      all.clear
    end

    def kill_worker
      job_queue.close
      yield if block_given?
      update_worker_status('dead')
      self.class.all.delete(self)
    end

    def retire_worker
      kill_worker do
        threads.each(&:join)
        threads.each do |thread|
          BackgroundThread.each_background_thread do |background_thread|
            if background_thread.thread == thread
              background_thread.kill_thread
            end
          end
          threads.delete(thread)
        end
      end
    end

    # REFACTOR THIS
    def new_thread
      threads << thread = Thread.new do
        if thread.nil?
          threads.delete(nil)
          next
        end

        background_thread = BackgroundThread.new(id, thread)

        while job_queue_open?
          background_thread.mode = Thread.current[:mode] = 'waiting'
          job = wait_for_job

          if job && deleted_jobs.include?(job.id)
            deleted_jobs.delete(job.id)
            next
          elsif job
            background_thread.mode = Thread.current[:mode] = 'processing'
            job.background_thread_id = background_thread.id
            job.run
          end
        end
      end

      retire_worker unless job_queue_open?
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
