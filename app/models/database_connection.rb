require "pg"

class DatabaseConnection
  def initialize#(logger)
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          else
            PG.connect(dbname: "maze_craze")
          end
    # @logger = logger
  end

  def query(statement, *params)
    # @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def disconnect
    @db.close
  end
end