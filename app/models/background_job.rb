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

      PROBLEM:
      sort order can have negative values.
        the lowest negative value becomes 0, the next becomes 1, etc.

      sort order can have values that are greater than the queue count
        the greatest value should become queue_count, the next should become queue_count - 1, etc.

      when values are adjusted 'down' for sort orders that are greater than queue_count,
        they can 'push into' or duplicate other new sort orders, like this:

        queue_count = 10
        1 - new sort_order
        2 - new sort_order

        8 - new sort_order
        7 - adjusted sort_order (due to sort_order being greater than queue_count)
        8 - adjusted sort_order (due to sort_order being greater than queue_count)
        9 - adjusted sort_order (due to sort_order being greater than queue_count)
        10 - adjusted sort_order (due to sort_order being greater than queue_count)

        the '8 - new sort_order' will have to be adjusted to 6

      idea:
      allow sort orders to be 2 decimal places
      upon submission, convert all updated sort_orders to two decimal places
      starting at .00001 and incrementing by .00001, add the number to the new sort_order so it will be like this

      1.10
      1.11 (duplicate) 
      1.11 (duplicate)
      1.12
      2.00

      becomes...

      1.10001
      1.11002 (not duplicate any more, and order is perserved) 
      1.11003 (not duplicate any more, and order is perserved)
      1.12004
      2.00005

      .00001 will allow for 999 submitted sort orders, which is way more than will ever be requested

      .00001 is a constant so it can be easily adjusted

      adding this to each new_sort_order will preserve the order in which they were submitted, if any were duplicates

      METHOD: adjust ascending
        sort new_sort_orders ASC.
        sort_order = 0
        iterate through new_sort_orders

        if new_sort_order <= queue_count && new_sort_order > sort_order
          sort_order = new_sort_order + 1
          next
        else if new_sort_order < sort_order
          new_sort_order = sort_order (WE NEED TO PRESERVE FLOATS)
        end 

        if new_sort_order <= sort_order # this will always be new_sort_order == sort_order because new_sort_order is set to sort_order
          sort_order += 1
        end

        # two scenarios to increase sort_order (see above if statement):
        #   if new_sort_order < sort_order
        #   if new_sort_order === sort_order
        # sort_order += 1 # what about queue_count?

        queue_count = 10
        -5
        -1
        0
        1
        3
        11
        12
        14
        14
        15

        iteration 1
        queue_count = 10
        => -5 becomes 1
        -1
        0
        1
        3
        11
        12
        14
        14
        15

        iteration 2
        queue_count = 10
        => -5 becomes 1
        => -1 becomes 2
        0
        1
        3
        11
        12
        14
        14
        15

        iteration 3
        queue_count = 10
        => -5 becomes 1
        => -1 becomes 2
        => 0 becomes 3
        1
        3
        11
        12
        14
        14
        15

        iteration 4
        queue_count = 10
        => -5 becomes 1
        => -1 becomes 2
        => 0 becomes 3
        => 1 becomes 4
        3
        11
        12
        14
        14
        15

        iteration 5
        queue_count = 10
        => -5 becomes 1
        => -1 becomes 2
        => 0 becomes 3
        => 1 becomes 4
        => 3 becomes 5
        11
        12
        14
        14
        15

      METHOD: adjust descending
          sort new_sort_orders DESC
          sort_order = queue_count
          iterate through new_sort_orders
          if new_sort_order < sort_order
            sort_order = new_sort_order - 1
            next
          else if new_sort_order > sort_order 
              new_sort_order = sort_order (WE NEED TO PRESERVE FLOATS)
          end
          
          if new_sort_order >= sort_order # this will always be new_sort_order == sort_order because new_sort_order is set to sort_order
            sort_order -=1
          end

          queue_count = 10
          15
          14
          14
          12
          11
          5
          4
          3
          2
          1

          iteration 1
          queue_count = 10
          => 15 becomes 10
          14
          14
          12
          11
          5
          4
          3
          2
          1

          iteration 2
          queue_count = 10
          => 15 becomes 10
          => 14 becomes 9
          14
          12
          11
          5
          4
          3
          2
          1

          iteration 3
          queue_count = 10
          => 15 becomes 10
          => 14 becomes 9
          => 14 becomes 8
          12
          11
          5
          4
          3
          2
          1

          iteration 4
          queue_count = 10
          => 15 becomes 10
          => 14 becomes 9
          => 14 becomes 8
          => 12 becomes 7
          11
          5
          4
          3
          2
          1

          iteration 5
          queue_count = 10
          => 15 becomes 10
          => 14 becomes 9
          => 14 becomes 8
          => 12 becomes 7
          => 11 becomes 6
          5
          4
          3
          2
          1

        ... the rest of the sort orders are preserved on the next 5 iterations

      def manually_sort_order(new_sort_values)
        new_sort_values =
          new_sort_values
          .select { |value| value['new_order'] != '' }

        correct_new_sort_values(new_sort_values).each do |value|
          job = job_from_id(value['job_id'].to_i)
          job.update_queue_order(value['new_order'].to_i)
        end

        old_sort_values =
          jobs_of_status_type('queued', 'queue_order', 'ASC')
          .reject { |job| new_sort_values.any? { |updated_job| job['id'] == updated_job['job_id'] } }
          .sort_by { |job| job['queue_order'].to_i }

        1.upto(queue_count) do |number|
          next if new_sort_values.any? { |job| number == job['new_order'].to_i }
          job = job_from_id(old_sort_values.first['id'].to_i)
          job.update_queue_order(number)
          old_sort_values.shift
        end
      end

      def correct_new_sort_values(new_sort_values)
        binding.pry
        # REFACTOR THIS
        new_sort_values = correct_duplicate_and_too_big_sort_orders(new_sort_values)
        correct_negative_sort_orders(new_sort_values)
      end

      def correct_duplicate_and_too_big_sort_orders(new_sort_values)
        # THIS IS NOT CORRECT
        # IT TURNS THIS:
        # [
        # {"job_id"=>"673", "new_order"=>"3.3"},
        # {"job_id"=>"666", "new_order"=>"3"},
        # {"job_id"=>"668", "new_order"=>"3.2"},
        # {"job_id"=>"669", "new_order"=>"3.1"}
        # ]
        # INTO
        # [
        # {"job_id"=>"673","new_order"=>3.3},
        # {"job_id"=>"666", "new_order"=>0}
        # {"job_id"=>"668", "new_order"=>2},
        # {"job_id"=>"669", "new_order"=>1}
        # ]

        # It should turn it into 3, 4, 5, 6
        # Not 0, 1, 2, 3

        new_sort_values =
          new_sort_values
          .sort { |thing1, thing2| thing2['new_order'].to_f <=> thing1['new_order'].to_f }

        greatest_available_queue_count_value = queue_count

        # queue_count = 10
        # Given: 25, 15, 10, 3, 3, 3

        # new_sort_values.each do |thing, _|
        #   new_order = thing['new_order'].to_i # 25, 15, 10, 3, 3, 3

        #   if new_order > greatest_available_queue_count_value # 25 > 10, 15 > 9, 10 > 8, 3 > 7, 3 > 2, 3 > 1, 3 > 0
        #     thing['new_order'] = greatest_available_queue_count_value # 10, 9, 8, 2, 1, 0
        #     greatest_available_queue_count_value -= 1 # 9, 8, 7, 1, 0, -1
        #   else
        #     thing['new_order'] = new_order # 3, 
        #     greatest_available_queue_count_value = new_order - 1 # 2
        #   end
        # end

        new_sort_values.each_with_index do |(thing, _), i|
          new_order = thing['new_order'].to_f

          if new_order > greatest_available_queue_count_value
            thing['new_order'] = greatest_available_queue_count_value
            greatest_available_queue_count_value -= 1
          else
            thing['new_order'] = new_order
            greatest_available_queue_count_value = new_order.to_i - 1
          end
        end

        new_sort_values
      end

      def correct_negative_sort_orders(new_sort_values)
        new_sort_values =
          new_sort_values
          .sort { |thing1, thing2| thing1['new_order'].to_f <=> thing2['new_order'].to_f }

        lowest_available_queue_count_value = 1

        new_sort_values.each do |thing, _|
          new_order = thing['new_order'].to_f

          if new_order < lowest_available_queue_count_value
            thing['new_order'] = lowest_available_queue_count_value
            lowest_available_queue_count_value += 1
          else
            lowest_available_queue_count_value = new_order.to_i + 1
          end
        end

        new_sort_values
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
