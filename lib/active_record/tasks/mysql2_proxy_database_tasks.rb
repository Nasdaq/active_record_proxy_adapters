# frozen_string_literal: true

require "active_record_proxy_adapters/database_tasks"

module ActiveRecord
  module Tasks
    # Defines the mysql tasks for dropping, creating, loading schema and dumping schema.
    # Bypasses all the proxy logic to send all requests to primary.
    class Mysql2ProxyDatabaseTasks < MySQLDatabaseTasks
      include ActiveRecordProxyAdapters::DatabaseTasks
    end
  end
end

# Allow proxy adapter to run rake tasks, i.e. db:drop, db:create, db:schema:load db:migrate, etc...
ActiveRecord::Tasks::DatabaseTasks.register_task(
  /mysql2_proxy/,
  "ActiveRecord::Tasks::Mysql2ProxyDatabaseTasks"
)
