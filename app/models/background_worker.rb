class BackgroundWorker
  MIN_THREADS = 1
  MAX_THREADS = 10

  attr_reader :db_id, :number_of_threads, :jobs
  attr_accessor :threads, :deleted_jobs

  @workers = []

  class << self
    attr_accessor :workers
  end

  def initialize(number_of_threads = 1)
    self.class.workers << self
    @db_id = nil
    @number_of_threads = number_of_threads
    @threads = []
    @deleted_jobs = []
    @jobs = Queue.new
    save_worker!
    set_db_id
    enqueue_jobs
    run
  end

  def self.query(sql, *params)
    db = DatabaseConnection.new
    results = db.query(sql, *params)
    db.disconnect
    results
  end

  def self.number_of_threads
    sql = 'SELECT integer_value FROM settings WHERE name = $1;'
    query(sql, 'number_of_threads').first['integer_value'].to_i
  end

  def self.update_number_of_threads(number)
    sql = 'UPDATE settings SET integer_value = $1, updated = $2 WHERE name = $3;'
    query(sql, number.to_i, 'NOW()', 'number_of_threads')
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
    sql = "UPDATE background_jobs SET worker_id = $1 WHERE id = $2;"
    query(sql, db_id, job['id'])
  end

  def self.active_worker
    workers.each do |worker|
      worker.threads.each do |thread|
        return worker if thread.alive? && worker.queue_open?
      end
    end
    nil
  end

  def self.object_id_from_db_id(db_id)
    sql = "SELECT object_id FROM background_workers WHERE id = $1;"
    query(sql, db_id)
  end

  def self.worker_from_object_id(object_id)
    workers.each { |worker| return worker if worker.object_id == object_id }
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
    sql = "DELETE FROM background_jobs WHERE id = $1;"
    query(sql, job_id)
  end

  def kill_job(thread_object_id)
    # undo what's been done so far
    # set status to 'queued'
    threads.each do |thread|
      return thread.kill if thread.object_id == thread_object_id
    end
  end

  private

  def query(sql, *params)
    db = DatabaseConnection.new
    results = db.query(sql, *params)
    db.disconnect
    results
  end

  def save_worker!
    sql = "INSERT INTO background_workers (object_id) VALUES($1);"
    query(sql, object_id)
  end

  def update_worker_is_dead!
    sql = "UPDATE background_workers SET status = $1, updated = $2;"
    query(sql, 'dead', 'NOW()')
  end

  def retrieve_worker_db_id
    sql = "SELECT id FROM background_workers WHERE object_id = $1;"
    query(sql, object_id)
  end

  def set_db_id
    @db_id = retrieve_worker_db_id.first['id']
  end

  def run # rename to work
    number_of_threads.times do
      threads << Thread.new do
        while queue_open? || jobs?
          job = wait_for_job
          if job && deleted_jobs.include?(job[:id])
            deleted_jobs.delete(job[:id])
            next
          elsif job
            job[:worker_id] = db_id
            job[:thread_object_id] = Thread.current.object_id
            BackgroundJob.new(job).run
          end
        end
      end
      stop! unless queue_open? || jobs?
    end
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
    update_worker_is_dead!
    self.class.workers.delete(self)
    true
  end
end
