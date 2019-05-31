class BackgroundJob
  JOB_TYPES = %w(generate_maze_formulas
                 generate_maze_permutations
                 generate_maze_candidates).freeze

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
