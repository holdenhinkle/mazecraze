class BackgroundJob
  JOB_TYPES = %w(generate_maze_formulas
                 generate_maze_permutations
                 generate_maze_candidates).freeze

  JOB_STATUSES = %w(running queued completed failed).freeze

  attr_reader :id, :type, :params, :worker_id, :thread_object_id

  def initialize(job)
    @id = job[:id] # refactor - doesn't exist when first saving to db
    @type = job[:type]
    @params = job[:params] # refactor - sometimes doesn't exist - depends on job type
    @worker_id = job[:worker_id]
    @thread_object_id = job[:thread_object_id]
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
    sql = "SELECT * FROM background_jobs WHERE status = $1 ORDER BY created DESC;"
    query(sql, status)
  end

  def self.last_job_added
    sql = "SELECT id, job_type, params FROM background_jobs ORDER BY created DESC LIMIT 1;"
    query(sql)
  end

  def save!
    sql = "INSERT INTO background_jobs (job_type, params) VALUES ($1, $2);"
    query(sql, type, params.to_json)
  end

  def update_job_is_running
    sql = "UPDATE background_jobs SET status = $1, worker_id = $2, thread_object_id = $3, updated = $4 WHERE id = $5;"
    query(sql, 'running', worker_id, thread_object_id, 'NOW()', id)
  end

  def update_job_status(status)
    sql = "UPDATE background_jobs SET status = $1, updated = $2 WHERE id = $3;"
    query(sql, status, 'NOW()', id)
  end

  def run
    send(type) if respond_to?(type.to_sym, :include_private) && JOB_TYPES.include?(type)
  end

  private

  def query(sql, *params)
    db = DatabaseConnection.new
    results = db.query(sql, *params)
    db.disconnect
    results
  end

  def generate_maze_formulas
    update_job_is_running
    if params.empty?
      generated_formula_stats = MazeFormula.generate_formulas
    else
      maze_formula_class = MazeFormula.maze_formula_type_to_class(params['maze_type'])
      generated_formula_stats = MazeFormula.generate_formulas([maze_formula_class]) # refactor - i don't like that I have to pass a one element array
    end
    new_message = "#{generated_formula_stats[:new]} new maze formulas were created."
    existed_message = "#{generated_formula_stats[:existed]} formulas already existed."
    AdminNotification.new(new_message + ' ' + existed_message).save!
    update_job_status('completed')
  end

  def generate_maze_permutations
  end

  def generate_maze_candidates
  end
end
