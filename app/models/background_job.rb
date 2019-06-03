class BackgroundJob
  JOB_TYPES = %w(generate_maze_formulas
                 generate_maze_permutations
                 generate_maze_candidates).freeze

  JOB_STATUSES = %w(queued processing completed failed).freeze

  attr_reader :type, :params

  def initialize(job)
    @type = job[:type]
    @params = job[:params]
  end

  def self.query(sql, *params)
    db = DatabaseConnection.new
    results = db.query(sql, *params)
    db.disconnect
    results
  end

  def self.all_jobs
    JOB_STATUSES.each_with_object({}) do |status, jobs|
      sql = "SELECT * FROM background_jobs WHERE status = $1 ORDER BY updated DESC LIMIT 10;"
      jobs[status] = query(sql, status)
      sql = "SELECT COUNT(id) FROM background_jobs WHERE status = $1;"
      jobs[status + '_count'] = query(sql, status)
    end
  end

  def self.all_jobs_of_status_type(status)
    sql = "SELECT * FROM background_jobs WHERE status = $1 ORDER BY updated DESC;"
    query(sql, status)
  end

  def self.next_queued_job
    sql = "SELECT * FROM background_jobs WHERE status = $1 ORDER BY created LIMIT 1;"
    query(sql, 'queued')
  end

  def save!
    sql = "INSERT INTO background_jobs (job_type, params) VALUES ($1, $2);"
    query(sql, type, params)
  end

  def run
    obj.send(type) if obj.respond_to?(type) && JOB_TYPES.include?(type)
  end

  private

  def query(sql, *params)
    db = DatabaseConnection.new
    results = db.query(sql, *params)
    db.disconnect
    results
  end

  def generate_maze_formulas
    generated_formula_stats = MazeFormula.generate_formulas
    new_message = "#{generated_formula_stats[:new]} new maze formulas were created."
    existed_message = "#{generated_formula_stats[:existed]} formulas already existed."
    AdminNotification.new(new_message + ' ' + existed_message).save!
  end

  def generate_maze_permutations
  end

  def generate_maze_candidates
  end

  def update_job_status
  end
end
