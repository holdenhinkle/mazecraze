module MazeCraze
  class BackgroundJob
    extend MazeCraze::Queryable
    include MazeCraze::Queryable

    JOB_TYPE_CLASS_NAMES = { 
      'generate_formulas' => 'GenerateFormulas',
      'generate_permutations' => 'GeneratePermutations',
      'generate_mazes' => 'GenerateMazes'
    }

    JOB_STATUSES = %w(running queued completed).freeze

    class << self
      def new_background_job(job_type, job_params)
        job_class = job_type_to_class(job_type)
        job_values = { 'job_type' => job_type, 'params' => job_params }
        job = job_class.new(job_values)
        worker = MazeCraze::BackgroundWorker.instance

        if worker.dead?
          worker.start
        else
          worker.enqueue_job(job.id)
          worker.start if worker.dead?
        end
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
        job_values = query(sql, job_id)[0]
        job_type_to_class(job_values['job_type']).new(job_values)
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

      def jobs_of_status_type(status, order_by ='created', sort_order = 'DESC')
        sql = "SELECT * FROM background_jobs WHERE status = $1 ORDER BY $2 #{sort_order};"
        query(sql, status, order_by)
      end

      def duplicate_job?(type, params = nil)
        duplicate_jobs(type, params).any?
      end

      def duplicate_jobs(type, params = nil)
        sql = "SELECT * FROM background_jobs WHERE job_type = $1 AND params = $2;"
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

      def manually_sort_queue_order(updated_queue_values)
        updated_queue_values =
          updated_queue_values
          .select { |job| job['new_queue_order'] != '' }
          .sort { |job1, job2| job2['new_queue_order'].to_i <=> job1['new_queue_order'].to_i }

        clean_updated_queue_order(updated_queue_values).each do |job_values|
          job = job_from_id(job_values['job_id'].to_i)
          job.update_queue_order(job_values['new_queue_order'].to_i)
        end

        not_updated_queue_values = jobs_of_status_type('queued', 'queue_order', 'ASC')
                                   .reject { |job| updated_queue_values.any? { |updated_job| job['id'] == updated_job['job_id'] } }
                                   .sort_by { |job| job['queue_order'].to_i }

        1.upto(queue_count) do |number|
          next if updated_queue_values.any? { |job| number == job['new_queue_order'].to_i }
          job = job_from_id(not_updated_queue_values.first['id'].to_i)
          job.update_queue_order(number)
          not_updated_queue_values.shift
        end
      end

      def clean_updated_queue_order(updated_queue_values)
        greatest_available_queue_count_value = queue_count

        updated_queue_values.each do |job, _|
          if job['new_queue_order'].to_i > greatest_available_queue_count_value
            job['new_queue_order'] = greatest_available_queue_count_value
            greatest_available_queue_count_value -= 1
          else
            greatest_available_queue_count_value = job['new_queue_order'].to_i - 1
          end
        end
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
        @id = save!
        updates_to_sync = [{ operation: 'update_job_status', status: 'queued'},
                           { operation: 'update_queue_order', for: 'new_job' }]
        sync_updates_that_can_affect_queue_order(updates_to_sync)
      end
    end

    def save!
      sql = "INSERT INTO background_jobs (job_type, params) VALUES ($1, $2) RETURNING id;"
      query(sql, type, params.to_json).first['id']
    end

    def sync_updates_that_can_affect_queue_order(updates, thread = nil)
      if thread
        sync_updates(updates)
      else
        threads = []
        threads << Thread.new do
          sync_updates(updates)
        end
        threads.each(&:join)
      end
    end

    def sync_updates(updates)
      MazeCraze::BackgroundWorker.mutex.synchronize do
        updates.each do |update|
          case update[:operation]
          when 'update_job_status' then update_job_status(update[:status])
          when 'update_queue_order' then update_queue_order_for(update[:for])
          when 'delete_from_db' then delete_from_db
          when 'reset' then reset
          end
        end
      end
    end

    def update_queue_order_for(situation)
      case situation
      when 'new_job' then update_queue_order_for_new_job
      when 'running_job' then update_queue_order_for_running_job
      when 'cancel_job' then update_queue_order_for_cancel_job
      when 'delete_job' then update_queue_order_for_delete_job
      end
    end

    def update_queue_order_for_new_job
      update_queue_order(self.class.queue_count) # same as for_cancel_job now
    end

    def update_queue_order_for_running_job
      update_queue_order(nil)
      self.class.decrement_queued_jobs_queue_order
    end

    def update_queue_order_for_cancel_job
      update_queue_order(self.class.queue_count) # same as for_new_job now
    end

    def update_queue_order_for_delete_job
      sql = 'SELECT * FROM background_jobs WHERE queue_order > $1 ORDER BY queue_order;'
      query(sql, queue_order).each do |job|
        job = self.class.job_from_id(job['id'])
        job.update_queue_order(job.queue_order - 1)
      end
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

    def update_time(time_column)
      sql = "UPDATE background_jobs SET #{time_column} = $1, updated = $2 WHERE id = $3;"
      query(sql, 'NOW()', 'NOW()', id)
    end

    def update_values_to_start_job(thread_id)
      update_job_thread_id(thread_id)
      updates_to_sync = [{ operation: 'update_job_status', status: 'running' },
                         { operation: 'update_queue_order', for: 'running_job' }]
      sync_updates_that_can_affect_queue_order(updates_to_sync, background_thread)
    end

    def start
      update_time('start_time')
      results = run
      update_time('finish_time')
      finish
      save_results(results)
      new_job_as_a_result_of_this_job
    end

    def cancel
      kill_thread
      undo
      updates_to_sync = [{ operation: 'reset' },
                         { operation: 'update_queue_order', for: 'cancel_job' }]
      sync_updates_that_can_affect_queue_order(updates_to_sync)
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
        updates_to_sync = [{ operation: 'delete_from_db' },
                           { operation: 'update_queue_order', for: 'delete_job'}]
        sync_updates_that_can_affect_queue_order(updates_to_sync)
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

    def background_thread_object
      MazeCraze::BackgroundThread.thread_from_id(background_thread_id)
    end

    def background_thread
      background_thread_object.thread
    end

    def kill_thread
      background_thread_object.kill_thread
    end
  end

  class GenerateFormulas < BackgroundJob
    def run
      if params.empty?
        formula_classes = MazeCraze::Formula.maze_formula_classes
        MazeCraze::Formula.generate_formulas(id, formula_classes)
      else
        formula_class = MazeCraze::Formula.formula_type_to_class(params['maze_type'])
        MazeCraze::Formula.generate_formulas(id, formula_class)
      end
    end

    def finish
      updates_to_sync = [{ operation: 'update_job_status', status: 'completed' }]
      sync_updates_that_can_affect_queue_order(updates_to_sync, background_thread)
    end

    def save_results(results)
      alert = "#{results[:new]} formulas were created. "
      alert << "#{results[:existed]} formulas already existed."
      MazeCraze::AdminNotification.new(alert).save!
    end

    def new_job_as_a_result_of_this_job; end

    def undo
      sql = "DELETE FROM formulas WHERE background_job_id = $1;"
      query(sql, id)
    end
  end

  class GeneratePermutations < BackgroundJob
    def run
      values = MazeCraze::Formula.formula_values(params['formula_id']).first
      formula = MazeCraze::Formula.formula_type_to_class(values['maze_type']).new(values)
      MazeCraze::Permutation.generate_permutations(formula)
    end

    def finish
      updates_to_sync = [{ operation: 'update_job_status', status: 'completed' }]
      sync_updates_that_can_affect_queue_order(updates_to_sync, background_thread)
      MazeCraze::Formula.update_status(params['formula_id'], 'completed')
    end

    def save_results(results)
      alert = "#{results} new permutations were created from Formula ID #{params['formula_id']}."
      MazeCraze::AdminNotification.new(alert).save!
    end

    def new_job_as_a_result_of_this_job
      job_type = 'generate_mazes'
      job_params = { 'formula_id' => params['formula_id'] }
      self.class.new_background_job(job_type, job_params)
    end

    def undo
      if status == 'running'
        sql = "DELETE FROM permutations WHERE background_job_id = $1;"
        query(sql, id)
      end

      MazeCraze::Formula.update_status(params['formula_id'], 'pending')
    end
  end

  class GenerateMazes < BackgroundJob
    def run
      MazeCraze::Maze.generate_mazes(params['formula_id'])
    end

    def finish
      updates_to_sync = [{ operation: 'update_job_status', status: 'completed' }]
      sync_updates_that_can_affect_queue_order(updates_to_sync, background_thread)
      MazeCraze::Permutation.update_status(params['formula_id'], 'completed')
    end

    def save_results(results)
      alert = "#{results} new mazes were created from Formula ID #{params['formula_id']}."
      MazeCraze::AdminNotification.new(alert).save!
    end

    def new_job_as_a_result_of_this_job; end

    def undo
      if status == 'running'
        sql = "DELETE FROM mazes WHERE background_job_id = $1;"
        query(sql, id)
      end

      MazeCraze::Permutation.update_status(params['formula_id'], 'pending')
    end
  end
end
