require 'active_support/concern'

module ActiveRecordExtension

  extend ActiveSupport::Concern

  # add your instance methods here
  # execute sql statements via activerecord
  def execute(*params)
    sql = sanitize_sql_array(params)
    ActiveRecord::Base.connection.exec_query(sql)
  end

  # add your static(class) methods here
  class_methods do
    # execute sql statements via activerecord
    def self.execute(*params)
      sql = sanitize_sql_array(params)
      ActiveRecord::Base.connection.exec_query(sql)
    end
  end
end

# include the extension 
ActiveRecord::Base.send(:include, ActiveRecordExtension)
