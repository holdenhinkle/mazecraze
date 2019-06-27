class BackgroundThread

  @all = []

  class << self
    attr_accessor :all
  end

  attr_reader :thread
  attr_accessor :id, :status

  def initialize(background_worker_id, thread)
    self.class.all << self
    @id = nil
    @thread = thread
    @status = 'alive'
    save!(background_worker_id)
  end

  def save!(background_worker_id)
    sql = 'INSERT INTO background_threads (background_worker_id, status) VALUES ($1, $2) RETURNING id;'
    self.id = query(sql, background_worker_id, status).first['id']
  end

  def update_thread_status(thread_status)
    self.status = thread_status
    sql = "UPDATE background_threads SET status = $1, updated = $2 WHERE id = $3;"
    query(sql, status, 'NOW()', id)
  end

  private

  def query(sql, *params)
    db = DatabaseConnection.new
    results = db.query(sql, *params)
    db.disconnect
    results
  end
end
