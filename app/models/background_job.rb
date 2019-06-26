class BackgroundJob
  JOB_TYPES = %w(generate_maze_formulas
                 generate_maze_permutations
                 generate_maze_candidates).freeze

  JOB_STATUSES = %w(running queued completed failed).freeze

  @all = []

  class << self
    attr_accessor :all
  end

  attr_reader :type, :params, :thread_id
  attr_accessor :id, :background_worker_id,
                :background_thread_id, :status

  def initialize(job)
    self.class.all << self
    @id = job[:id]
    @background_worker_id = nil
    @background_thread_id = nil
    @type = job[:type]
    @params = job[:params]
    @status = 'queued'
    save!
  end

  def self.query(sql, *params)
    db = DatabaseConnection.new
    results = db.query(sql, *params)
    db.disconnect
    results
  end

  def self.job_from_id(job_id)
    all.each { |job| return job if job.id == job_id }
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

  def self.delete_job_from_db(job_id)
    # all results from running this job will be deleted when job is deleted from database
    sql = "DELETE FROM background_jobs WHERE id = $1;"
    query(sql, job_id)
  end

  def save!
    sql = "INSERT INTO background_jobs (job_type, params, status) VALUES ($1, $2, $3) RETURNING id;"
    self.id = query(sql, type, params.to_json, status).first['id']
  end

  def update_job_is_running
    self.status = 'running'
    sql = "UPDATE background_jobs SET status = $1, background_thread_id = $2, updated = $3 WHERE id = $4;"
    query(sql, status, background_thread_id, 'NOW()', id)
  end

  def update_job_status(job_status)
    self.status = job_status
    sql = "UPDATE background_jobs SET status = $1, updated = $2 WHERE id = $3;"
    query(sql, status, 'NOW()', id)
  end

  def update_job_thread_id(thread_id)
    self.background_thread_id = thread_id
    sql = "UPDATE background_jobs SET background_thread_id = $1, updated = $2 WHERE id = $3;"
    query(sql, background_thread_id, 'NOW()', id)
  end

  def run
    send(type) if respond_to?(type.to_sym, :include_private) &&
                  JOB_TYPES.include?(type)
  end

  # def undo
  #   method_name = 'undo_' + type
  #   send(method_name) if respond_to?(method_name.to_sym, :include_private) &&
  #                        JOB_TYPES.include?(type)
  # end

  def undo
    table_name = case type
                 when 'generate_maze_formulas'
                   'maze_formulas'
                 when 'generate_maze_permutations'
                   'maze_formula_set_permutations'
                 when 'generate_maze_candidates'
                   'maze_candidates'
                 end

    sql = "DELETE FROM #{table_name} WHERE background_job_id = $1;"
    query(sql, id)
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
      generated_formula_stats = MazeFormula.generate_formulas(id.to_i)
    else
      maze_formula_class = MazeFormula.maze_formula_type_to_class(params['maze_type'])
      generated_formula_stats = MazeFormula.generate_formulas(id.to_i, [maze_formula_class]) # refactor - i don't like that I have to pass a one element array
    end
    new_message = "#{generated_formula_stats[:new]} new maze formulas were created."
    existed_message = "#{generated_formula_stats[:existed]} formulas already existed."
    AdminNotification.new(new_message + ' ' + existed_message).save!
    update_job_status('completed')
    # remove job from jobs array - doesn't need to exist in memory anymore because it will never be used again
  end

  def generate_maze_permutations
  end

  def generate_maze_candidates
  end

  # def undo_generate_maze_formulas
  #   sql = 'DELETE FROM maze_formulas WHERE background_job_id = $1;'
  #   query(sql, id)
  # end

  # def undo_generate_maze_permutations
  # end

  # def undo_generate_maze_candidates
  # end
end
