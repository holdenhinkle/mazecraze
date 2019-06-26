class BackgroundThread

  @all = []

  class << self
    attr_accessor :all
  end

  attr_reader :thread
  attr_accessor :id

  def initialize(background_worker_id, thread)
    self.class.all << self
    @id = nil
    @thread = thread
    save!(background_worker_id)
  end

  def save!(background_worker_id)
    sql = 'INSERT INTO background_threads (background_worker_id) VALUES ($1) RETURNING id;'
    self.id = query(sql, background_worker_id).first['id']
  end

  private

  def query(sql, *params)
    db = DatabaseConnection.new
    results = db.query(sql, *params)
    db.disconnect
    results
  end
end
