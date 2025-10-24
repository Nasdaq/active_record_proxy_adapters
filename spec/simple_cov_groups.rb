# frozen_string_literal: true

SIMPLE_COV_GROUPS = proc do
  add_group "Core" do |src_file|
    [
      /active_record_context/,
      /configuration/,
      /context/,
      /contextualizer/,
      %r{/database_tasks},
      /errors/,
      /hijackable/,
      /middleware/,
      /mixin/,
      /primary_replica_proxy/,
      /core/
    ].any? { |pattern| pattern.match?(src_file.filename) }
  end

  add_group "PostgreSQL" do |src_file|
    [/postgresql/, /postgre_sql/].any? { |pattern| pattern.match?(src_file.filename) }
  end

  add_group "MySQL2" do |src_file|
    /mysql2/.match?(src_file.filename)
  end

  add_group "Trilogy" do |src_file|
    /trilogy/.match?(src_file.filename)
  end

  add_group "SQLite3" do |src_file|
    /sqlite3/.match?(src_file.filename)
  end
end
