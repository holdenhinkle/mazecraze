require 'active_support/concern'

module ActiveRecordExtension

  extend ActiveSupport::Concern

  # execute sql statements via activerecord
  def execute(*params)
    sql = sanitize_sql_array(params)
    ActiveRecord::Base.connection.exec_query(sql)
  end

  class_methods do
    def execute(*params)
      # execute sql statements via activerecord
      sql = sanitize_sql_array(params)
      ActiveRecord::Base.connection.exec_query(sql)
    end
  end
end

# include the extension 
ActiveRecord::Base.send(:include, ActiveRecordExtension)
