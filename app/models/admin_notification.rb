class AdminNotification
  include MazeCraze::Queryable
  
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
end
