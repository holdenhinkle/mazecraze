class BackgroundWorker
  MIN_THREADS = 1
  MAX_THREADS = 10

  @all = []

  class << self
    attr_accessor :all
  end

  attr_reader :number_of_threads, :jobs
  attr_accessor :id, :threads, :deleted_jobs

  def initialize
    self.class.all << self
    @id = nil
    @number_of_threads = self.class.number_of_threads
    @threads = []
    @deleted_jobs = []
    @jobs = Queue.new
    save!
    enqueue_jobs
    work
  end

  def self.query(sql, *params)
    db = DatabaseConnection.new
    results = db.query(sql, *params)
    db.disconnect
    results
  end

  def self.worker_from_id(worker_id)
    all.each { |worker| return worker if worker.id == worker_id }
  end

  def self.number_of_threads
    sql = 'SELECT integer_value FROM settings WHERE name = $1;'
    query(sql, 'number_of_threads').first['integer_value'].to_i
  end

  def self.update_number_of_threads(number)
    sql = 'UPDATE settings SET integer_value = $1, updated = $2 WHERE name = $3;'
    query(sql, number, 'NOW()', 'number_of_threads')
    # kill current threads
    # stop worker
    # start new worker
  end

  def enqueue_jobs
    BackgroundJob.all.each { |job| enqueue_job(job) if job.status == 'queued' }
  end

  def enqueue_job(job)
    jobs << job
    sql = 'UPDATE background_jobs SET background_worker_id = $1, updated = $2 WHERE id = $3;'
    query(sql, id, 'NOW()', job.id)
  end

  def self.active_worker
    all.each do |worker|
      worker.threads.each do |thread|
        return worker if thread.alive? && worker.queue_open?
      end
    end
    nil
  end

  def still_active?
    return true if threads.any?(&:alive?) && queue_open?
    false
  end

  def queue_open?
    !jobs.closed?
  end

  def delete_job(job_id)
    deleted_jobs << job_id
  end

  def kill_one_job(thread_id, job_id)
    BackgroundThread.all.each do |background_thread|
      if background_thread.id == thread_id
        thread = background_thread.thread
        kill_job(thread, job_id) # kill thread job is running on
        threads.delete(thread) # delete thread from threads array
        new_thread # replace killed thread with new thread
        break
      end
    end
  end

  def kill_all_jobs
    # UPDATE THIS - MUST SEND job_id TO kill_job
    BackgroundThread.all.each { |thread| kill_job(thread) }
    stop!
  end

  def kill_job(thread, job_id)
    Thread.kill(thread)
    job = BackgroundJob.job_from_id(job_id)
    job.update_job_status('queued')
    job.update_job_thread_id(nil)
    job.undo
    enqueue_job(job)
  end

  private

  def query(sql, *params)
    db = DatabaseConnection.new
    results = db.query(sql, *params)
    db.disconnect
    results
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

  def new_thread
    threads << thread = Thread.new do
      thread = BackgroundThread.new(id, thread)
      while queue_open? || jobs?
        job = wait_for_job
        if job && deleted_jobs.include?(job.id)
          deleted_jobs.delete(job.id)
          next
        elsif job
          job.background_thread_id = thread.id
          job.run
        end
      end
    end
    stop! unless queue_open? || jobs?
  end

  def jobs?
    !jobs.empty?
  end

  def wait_for_job
    jobs.pop(false)
  end

  def stop!
    jobs.close
    threads.each(&:join).each(&:exit).clear
    update_worker_status('dead')
    self.class.all.delete(self)
  end
end
