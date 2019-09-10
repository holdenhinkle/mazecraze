module MazeCraze
  class BackgroundThread
    include MazeCraze::Queryable
    extend MazeCraze::Queryable

    MIN_THREADS = 1
    MAX_THREADS = 10

    @all = []

    class << self
      attr_accessor :all

      def number_of_threads
        sql = 'SELECT integer_value FROM settings WHERE name = $1;'
        query(sql, 'number_of_threads').first['integer_value'].to_i
      end

      def update_number_of_threads(number)
        sql = 'UPDATE settings SET integer_value = $1, updated = $2 WHERE name = $3;'
        query(sql, number, 'NOW()', 'number_of_threads')
      end

      def all_background_thread_threads
        all.map(&:thread)
      end

      def thread_from_id(thread_id)
        all.each do |background_thread| 
          return background_thread if background_thread.id == thread_id
        end
        nil
      end

      def thread_details(worker_id)
        details = []
        all.each do |background_thread|
          next unless background_thread.background_worker_id == worker_id
          details << { id: background_thread.id,
                       job_id: background_thread.background_job_id,
                       status: background_thread.thread.alive?,
                       mode: background_thread.mode }
        end
        details
      end

      def kill_all_threads
        all_copy = all.clone
        all_copy.each(&:kill_thread)
      end
    end

    attr_reader :id, :background_worker_id
    attr_accessor :thread, :background_job_id, :status, :mode

    def initialize(background_worker_id)
      self.class.all << self
      @background_worker_id = background_worker_id
      @status = 'alive'
      @mode = 'waiting'
      @id = save!
    end

    def kill_thread
      Thread.kill(thread)
      thread.join
      update_thread_status_to_dead
      self.class.all.delete(self)
    end

    def save!
      sql = 'INSERT INTO background_threads (background_worker_id, status) VALUES ($1, $2) RETURNING id;'
      query(sql, background_worker_id, status).first['id'].to_i
    end

    def update_thread_mode_and_background_job_id(updated_mode, updated_background_job_id)
      self.mode = updated_mode
      self.background_job_id = updated_background_job_id
    end

    def update_thread_status_to_dead
      self.status = 'dead'
      sql = "UPDATE background_threads SET status = $1, updated = $2 WHERE id = $3;"
      query(sql, status, 'NOW()', id)
    end
  end
end
