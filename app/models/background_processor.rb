class BackgroundProcessor
  def initialize; end

  def self.query(sql, *params)
    db = DatabaseConnection.new
    results = db.query(sql, *params)
    db.disconnect
    results
  end

  def save!; end

  def run
    job = next_queued_job
  end

  private

  def query(sql, *params)
    db = DatabaseConnection.new
    results = db.query(sql, *params)
    db.disconnect
    results
  end

  def next_queued_job
    sql = "SELECT id, job_type, params FROM background_jobs ORDER BY created LIMIT 1;"
    query(sql)
  end
end
