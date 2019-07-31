module MazeCraze
  class BackgroundJob
    extend MazeCraze::Queryable
    include MazeCraze::Queryable

    JOB_TYPES = %w(generate_maze_formulas
                   generate_maze_permutations
                   generate_maze_candidates).freeze

    JOB_STATUSES = %w(running queued completed failed).freeze

    @all = []
    @queue_count = 0

    class << self
      attr_accessor :all, :queue_count
    end

    def self.each_job
      all.each { |job| yield(job) }
    end

    def self.job_from_id(job_id)
      each_job { |job| return job if job.id == job_id }
    end

    def self.each_running_job
      each_job { |job| yield(job) if job.status == 'running'}
    end

    def self.each_queued_job
      each_job { |job| yield(job) if job.status == 'queued'}
    end

    def self.undo_running_jobs
      each_running_job(&:undo)
    end

    def self.reset_running_jobs
      each_running_job(&:reset)
    end

    def self.update_queue_order
      sql = 'SELECT * FROM background_jobs WHERE status = $1 ORDER BY updated;'
      running_jobs = query(sql, 'running')

      update_queued_jobs_queue_order(running_jobs)
      update_running_jobs_queue_order(running_jobs)
    end

    def self.update_queued_jobs_queue_order(running_jobs)
      each_queued_job do |job|
        job.queue_order += running_jobs.count
        job.update_queue_order
      end
    end

    def self.update_running_jobs_queue_order(running_jobs)
      running_jobs.each_with_index do |job, index|
        self.queue_count += 1
        job = job_from_id(job['id'])
        job.queue_order = index + 1
        job.update_queue_order
      end
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

    def self.duplicate_job?(type, params = nil)
      duplicate_jobs(type, params).any?
    end

    def self.duplicate_jobs(type, params = nil)
      sql = 'SELECT * FROM background_jobs WHERE job_type = $1 AND params = $2;'
      query(sql, type, params.to_json)
    end

    def self.update_queue_orders
      each_job do |job|
        next unless job.status == 'queued'
        job.queue_order -= 1
        job.update_queue_order
      end
    end

    attr_reader :type, :params, :thread_id
    attr_accessor :id, :queue_order, :background_worker_id,
                  :background_thread_id, :status

    def initialize(job)
      self.class.all << self
      @id = job[:id]
      @type = job[:type]
      @params = job[:params]
      @status = 'queued'
      self.class.queue_count += 1
      @queue_order = self.class.queue_count
      save!
    end

    def save!
      sql = "INSERT INTO background_jobs (job_type, params, status, queue_order) VALUES ($1, $2, $3, $4) RETURNING id;"
      self.id = query(sql, type, params.to_json, status, queue_order).first['id']
    end

    def update_queue_order
      sql = 'UPDATE background_jobs SET queue_order = $1 WHERE id = $2;'
      query(sql, queue_order, id)
    end

    def update_job_is_running(thread_id)
      self.background_thread_id = thread_id
      self.status = 'running'
      self.queue_order = nil
      sql = "UPDATE background_jobs SET background_thread_id = $1, status = $2, queue_order = $3, updated = $4 WHERE id = $5;"
      query(sql, background_thread_id, status, queue_order, 'NOW()', id)
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

    def reset
      update_job_status('queued')
      update_job_thread_id(nil)
    end

    # this is for jobs that are cancelled
    # def reset(new_queue_order = self.class.queue_count)
    #   self.queue_order = new_queue_order
    #   update_queue_order
    #   update_job_status('queued')
    #   update_job_thread_id(nil)
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

    def delete
      self.class.all.delete(self)
      sql = "DELETE FROM background_jobs WHERE id = $1;"
      query(sql, id)
    end

    def update_queue_order_because_of_deleted_job
      sql = 'SELECT * FROM background_jobs WHERE queue_order > $1 ORDER BY queue_order;'
      query(sql, queue_order).each do |job|
        job = self.class.job_from_id(job['id'])
        job.queue_order -= 1
        job.update_queue_order
      end
    end

    def delete_from_db
      self.class.all.delete(self)
      sql = "DELETE FROM background_jobs WHERE id = $1;"
      query(sql, id)
    end

    private

    def generate_maze_formulas
      if params.empty?
        generated_formula_stats = MazeCraze::MazeFormula.generate_formulas(id.to_i)
      else
        maze_formula_class = MazeCraze::MazeFormula.maze_formula_type_to_class(params['maze_type'])
        generated_formula_stats = MazeCraze::MazeFormula.generate_formulas(id.to_i, [maze_formula_class]) # refactor - i don't like that I have to pass a one element array
      end
      new_message = "#{generated_formula_stats[:new]} new maze formulas were created."
      existed_message = "#{generated_formula_stats[:existed]} formulas already existed."
      MazeCraze::AdminNotification.new(new_message + ' ' + existed_message).save!
      update_job_status('completed')
      # remove job from jobs array - doesn't need to exist in memory anymore because it will never be used again
    end

    def generate_maze_permutations
    end

    def generate_maze_candidates
    end
  end
end
