# frozen_string_literal: true

SIMPLE_COV_GROUPS = proc do
  add_group "PostgreSQL" do |src_file|
    [/postgresql/, /postgre_sql/].any? { |pattern| pattern.match?(src_file.filename) }
  end

  add_group "MySQL2" do |src_file|
    /mysql2/.match?(src_file.filename)
  end
end
