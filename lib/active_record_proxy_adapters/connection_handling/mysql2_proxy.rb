# frozen_string_literal: true

begin
  require "active_record/connection_adapters/mysql2_proxy_adapter"
rescue LoadError
  # mysql2 not available
  return
end
