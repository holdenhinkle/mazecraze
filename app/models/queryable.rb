module MazeCraze
  module Queryable
    def query(sql, *params)
      db = DatabaseConnection.new
      results = db.query(sql, *params)
      db.disconnect
      results
    end
  end
end
