class BackgroundJobProcessor
  attr_accessor :ppid, :pid

  def initialize
    @ppid = nil
    @pid = nil
  end

  def self.query(sql, *params)
    db = DatabaseConnection.new
    results = db.query(sql, *params)
    db.disconnect
    results
  end

  def save!; end

  def run
    while BackgroundJob.all_jobs_of_status_type('queued').values.any?
      job = BackgroundJob.next_queued_job.first
      pid = Process.fork do
        puts "Backgroud job, pid #{Process.pid}, processing..."
        ppid = Process.ppid
        log_new_process
        BackgroundJob.new({ type: job['job_type'], params: job['params'] }).run
        puts "Background job, finished, exiting"
      end
      puts "Background process, pid #{Process.pid}, waiting on background Job, pid #{pid}"
      Process.wait(pid)
      puts "Background process exiting"
      # update job
      # update process
    end
  end

  private

  def query(sql, *params)
    db = DatabaseConnection.new
    results = db.query(sql, *params)
    db.disconnect
    results
  end

  def log_new_process
    sql = "INSERT INTO background_processes (ppid) VALUES ($1);"
    query(sql, ppid)
  end
end
