# frozen_string_literal: true

begin
  require "active_record/connection_adapters/trilogy_proxy_adapter"
rescue LoadError
  # trilogy not available
  return
end
