class AdminNotification
  attr_reader :notification

  def initialize(notification)
    @notification = notification
  end

  def save!
    sql = "INSERT INTO admin_notifications (notification) VALUES ($1);"
    query(sql, notification)
  end

  def delivered!(id)
    sql = "UPDATE table admin_notifications SET delivered = $1, updated = $2 WHERE id = $3;"
    query(sql, TRUE, NOW, id)
  end

  private

  def query(sql, *params)
    db = DatabaseConnection.new
    results = db.query(sql, *params)
    db.disconnect
    results
  end
end
