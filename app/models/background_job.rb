class BackgroundJob
  JOB_TYPES = %w(generate_maze_formulas
                 generate_maze_permutations
                 generate_maze_candidates).freeze

  JOB_STATUSES = %w(queued processing completed failed).freeze

  attr_reader :job_type, :params

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

  def query(sql, *params)
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

  def work
    obj.send(type) if obj.respond_to?(type) && JOB_TYPES.include?(type)
  end

  private

  def generate_maze_formulas
  end

  def generate_maze_permutations
  end

  def generate_maze_candidates
  end
end
