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
    @mutex = Mutex.new

    class << self
      attr_reader :mutex
      attr_accessor :all, :queue_count

      def job_from_id(job_id)
        all.each { |job| return job if job.id == job_id }
      end

      def each_running_job
        all.each { |job| yield(job) if job.status == 'running'}
      end

      def each_queued_job
        all.each { |job| yield(job) if job.status == 'queued'}
      end

      def all_jobs
        JOB_STATUSES.each_with_object({}) do |status, jobs|
          sql = "SELECT * FROM background_jobs WHERE status = $1 ORDER BY updated DESC LIMIT 10;"
          jobs[status] = query(sql, status)
          sql = "SELECT COUNT(id) FROM background_jobs WHERE status = $1;"
          jobs[status + '_count'] = query(sql, status)
        end
      end

      def all_jobs_of_status_type(status)
        sql = "SELECT * FROM background_jobs WHERE status = $1 ORDER BY created DESC;"
        query(sql, status)
      end

      def duplicate_job?(type, params = nil)
        duplicate_jobs(type, params).any?
      end

      def duplicate_jobs(type, params = nil)
        sql = 'SELECT * FROM background_jobs WHERE job_type = $1 AND params = $2;'
        query(sql, type, params.to_json)
      end

      def update_queue_order_upon_stop
        sql = 'SELECT * FROM background_jobs WHERE status = $1 ORDER BY updated;'
        running_jobs = query(sql, 'running')

        update_queued_jobs_queue_order_upon_stop(running_jobs)
        update_running_jobs_queue_order_upon_stop(running_jobs)
      end

      def update_queued_jobs_queue_order_upon_stop(running_jobs)
        each_queued_job do |job|
          job.update_queue_order(job.queue_order + running_jobs.count)
        end
      end

      def update_running_jobs_queue_order_upon_stop(running_jobs)
        running_jobs.each_with_index do |job, index|
          self.queue_count += 1
          job = job_from_id(job['id'])
          job.update_queue_order(index + 1)
        end
      end

      def decrement_queued_jobs_queue_order
        each_queued_job { |job| job.update_queue_order(job.queue_order - 1) }
      end

      def undo_running_jobs
        each_running_job(&:undo)
      end

      def reset_running_jobs
        each_running_job(&:reset)
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
      update_queue_order_for('initialize_job')
      save!
    end

    def update_queue_order_for(sequence, thread = nil)
      if thread
        queue_order_sequence(sequence)
      else
        threads = []
        threads << Thread.new do
          queue_order_sequence(sequence)
        end
        threads.each(&:join)
      end
    end

    def queue_order_sequence(sequence)
      self.class.mutex.synchronize do
        case sequence
        when 'initialize_job' then update_queue_order_for_initialize_job
        when 'running_job' then update_queue_order_for_new_running_job
        when 'cancel_job' then update_queue_order_for_cancel_job
        when 'delete_job' then update_queue_order_for_delete_job
        end
      end
    end

    def update_queue_order_for_initialize_job
      self.queue_order = self.class.queue_count += 1
    end

    def update_queue_order_for_new_running_job
      self.class.queue_count -= 1
      update_queue_order(nil)
      self.class.decrement_queued_jobs_queue_order
    end

    def update_queue_order_for_cancel_job
      update_queue_order(self.class.queue_count += 1)
    end

    def update_queue_order_for_delete_job
      sql = 'SELECT * FROM background_jobs WHERE queue_order > $1 ORDER BY queue_order;'
      query(sql, queue_order).each do |job|
        job = self.class.job_from_id(job['id'])
        job.update_queue_order(job.queue_order - 1)
      end
    end

    def save!
      sql = "INSERT INTO background_jobs (job_type, params, status, queue_order) VALUES ($1, $2, $3, $4) RETURNING id;"
      self.id = query(sql, type, params.to_json, status, queue_order).first['id']
    end

    def update_job_status(new_job_status)
      self.status = new_job_status
      sql = "UPDATE background_jobs SET status = $1, updated = $2 WHERE id = $3;"
      query(sql, status, 'NOW()', id)
    end

    def update_job_thread_id(new_thread_id)
      self.background_thread_id = new_thread_id
      sql = "UPDATE background_jobs SET background_thread_id = $1, updated = $2 WHERE id = $3;"
      query(sql, background_thread_id, 'NOW()', id)
    end

    def update_queue_order(new_queue_order)
      self.queue_order = new_queue_order
      sql = 'UPDATE background_jobs SET queue_order = $1 WHERE id = $2;'
      query(sql, queue_order, id)
    end

    def run(thread_obj)
      update_job_thread_id(thread_obj.id)
      update_job_status('running')
      update_queue_order_for('running_job', thread_obj.thread)

      send(type) if respond_to?(type.to_sym, :include_private) &&
                    JOB_TYPES.include?(type)
    end

    def cancel
      kill_thread

      update_queue_order_for('cancel_job')
      undo
      reset

      worker = MazeCraze::BackgroundWorker.instance
      worker.enqueue_job(self)
      worker.new_thread
    end

    def delete(job_status)
      case job_status
      when 'running'
        kill_thread
        undo
        delete_from_db
        background_worker.new_thread
      when 'queued'
        background_worker.skip_job_in_queue(id)
        delete_from_db
        update_queue_order_for('delete_job')
      end
    end

    def reset
      update_job_status('queued')
      update_job_thread_id(nil)
    end

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

    def delete_from_db
      self.class.all.delete(self)
      sql = "DELETE FROM background_jobs WHERE id = $1;"
      query(sql, id)
    end

    private

    def background_worker
      MazeCraze::BackgroundWorker.instance
    end

    def kill_thread
      background_thread = MazeCraze::BackgroundThread.thread_from_id(background_thread_id)
      MazeCraze::BackgroundThread.all.delete(background_thread).kill_thread
    end

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

  class GenerateMazeFormulas < BackgroundJob
    def run; end

    def undo; end
  end

  class GenerateMazePermutations < BackgroundJob
    def run; end

    def undo; end
  end

  class GenerateMazeCandidates < BackgroundJob
    def run; end

    def undo; end
  end
end
