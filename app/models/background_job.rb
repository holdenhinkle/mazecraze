module MazeCraze
  class BackgroundJob
    extend MazeCraze::Queryable
    include MazeCraze::Queryable

    JOB_TYPE_CLASS_NAMES = { 
      'generate_maze_formulas' => 'GenerateMazeFormulasJob',
      'generate_maze_permutations' => 'GenerateMazePermutationJob',
      'generate_maze_candidates' => 'GenerateMazeCandidateJob'
    }

    JOB_STATUSES = %w(running queued completed failed).freeze

    class << self
      def sanitize_background_jobs_table
        sql = 'UPDATE background_jobs SET status = $1 WHERE status = $2;'
        query(sql, 'queued', 'running')

        sql = 'UPDATE background_jobs SET background_worker_id = $1, background_thread_id = $2 WHERE status = $3 OR status = $4;'
        query(sql, nil, nil, 'queued', 'running')
      end

      def queue_count
        sql = "SELECT COUNT(status) FROM background_jobs WHERE status = $1;"
        query(sql, 'queued').first['count'].to_i
      end

      def job_type_to_class(type)
        class_name = 'MazeCraze::' + JOB_TYPE_CLASS_NAMES[type]
        Kernel.const_get(class_name) if Kernel.const_defined?(class_name)
      end

      def job_from_id(job_id)
        sql = "SELECT * FROM background_jobs WHERE id = $1;"
        job = query(sql, job_id)[0]
        job_type_to_class(job['job_type']).new(job)
      end

      def each_running_job
        jobs = jobs_of_status_type('running').map do |job, _|
          job_from_id(job['id'])
        end

        jobs.each { |job| yield(job) }
      end

      def each_queued_job
        jobs = jobs_of_status_type('queued').map do |job, _|
          job_from_id(job['id'])
        end

        jobs.each { |job| yield(job) }
      end

      def all_jobs
        JOB_STATUSES.each_with_object({}) do |status, jobs|
          sql = "SELECT * FROM background_jobs WHERE status = $1 ORDER BY updated DESC LIMIT 10;"
          jobs[status] = query(sql, status)
          sql = "SELECT COUNT(id) FROM background_jobs WHERE status = $1;"
          jobs[status + '_count'] = query(sql, status)
        end
      end

      def jobs_of_status_type(status)
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
      @type = job['job_type']

      if job['id']
        @id = job['id'].to_i
        @queue_order = job['queue_order'].to_i
        @background_worker_id = job['background_worker_id'].to_i
        @background_thread_id = job['background_thread_id'].to_i
        @params = JSON.parse(job['params'])
        @status = job['status']
      else
        @params = job['params']
        @status = 'queued'
        @id = save!
        update_queue_order_for('new_job')
      end
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
        when 'new_job' then update_queue_order_for_new_job
        when 'running_job' then update_queue_order_for_running_job
        when 'cancel_job' then update_queue_order_for_cancel_job
        when 'delete_job' then update_queue_order_for_delete_job
        end
      end
    end

    def update_queue_order_for_new_job
      update_queue_order(self.class.queue_count)
    end

    def update_queue_order_for_running_job
      update_queue_order(nil)
      self.class.decrement_queued_jobs_queue_order
    end

    def update_queue_order_for_cancel_job
      update_queue_order(self.class.queue_count + 1)
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
      query(sql, type, params.to_json, status, queue_order).first['id']
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

    def update_start_time
      sql = 'UPDATE background_jobs SET start_time = $1, updated = $2 WHERE id = $3;'
      query(sql, 'NOW()', 'NOW()', id)
    end

    def update_finish_time
      sql = 'UPDATE background_jobs SET finish_time = $1, updated = $2 WHERE id = $3;'
      query(sql, 'NOW()', 'NOW()', id)
    end

    def prepare_to_run(thread_obj)
      update_job_thread_id(thread_obj.id)
      update_job_status('running')
      update_queue_order_for('running_job', thread_obj.thread)
      start
    end

    def start
      update_start_time
      results = run
      update_finish_time
      finish(results)
    end

    def finish(results)
      update_job_status('completed')
      alert = "#{results[:new]} formulas were created. "
      alert << "#{results[:existed]} formulas already existed."
      MazeCraze::AdminNotification.new(alert).save!
    end

    def cancel
      kill_thread
      update_queue_order_for('cancel_job') # not completed sometimes
      binding.pry if queue_order == nil
      undo # not completed sometimes
      reset # not completed sometimes
      binding.pry if status == 'running'
      background_worker.enqueue_job(id)
      background_worker.new_thread
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

    def delete_from_db
      sql = "DELETE FROM background_jobs WHERE id = $1;"
      query(sql, id)
    end

    private

    def background_worker
      MazeCraze::BackgroundWorker.instance
    end

    def kill_thread
      background_thread = MazeCraze::BackgroundThread.thread_from_id(background_thread_id)
      binding.pry if background_thread.nil?
      MazeCraze::BackgroundThread.all.delete(background_thread).kill_thread
    end
  end

  class GenerateMazeFormulasJob < BackgroundJob
    @mutex = Mutex.new

    class << self
      attr_reader :mutex
    end

    def run
      if params.empty?
        formula_classes = MazeCraze::MazeFormula.maze_formula_classes
        MazeCraze::MazeFormula.generate_formulas(id, formula_classes)
      else
        formula_class = MazeCraze::MazeFormula.maze_formula_type_to_class(params['maze_type'])
        MazeCraze::MazeFormula.generate_formulas(id, formula_class)
      end
    end

    def undo
      sql = "DELETE FROM maze_formulas WHERE background_job_id = $1;"
      query(sql, id)
    end
  end

  class GenerateMazePermutationJob < BackgroundJob
    def run; end

    def undo
      sql = "DELETE FROM maze_formula_set_permutations WHERE background_job_id = $1;"
      query(sql, id)
    end
  end

  class GenerateMazeCandidateJob < BackgroundJob
    def run; end

    def undo
      sql = "DELETE FROM maze_candidates WHERE background_job_id = $1;"
      query(sql, id)
    end
  end
end
