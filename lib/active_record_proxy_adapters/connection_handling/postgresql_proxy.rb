# frozen_string_literal: true

begin
  require "active_record/connection_adapters/postgresql_proxy_adapter"
rescue LoadError
  # Postgres not available
  return
end
