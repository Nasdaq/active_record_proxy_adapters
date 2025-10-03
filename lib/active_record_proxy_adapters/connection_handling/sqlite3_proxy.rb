# frozen_string_literal: true

begin
  require "active_record/connection_adapters/sqlite3_proxy_adapter"
rescue LoadError
  # sqlite3 not available
  return
end
