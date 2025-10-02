# frozen_string_literal: true

require "active_support"
require "active_record_proxy_adapters/core"

module ActiveRecordProxyAdapters
  module Railties
    # Hooks into rails boot process to load the Trilogy Proxy adapter.
    class TrilogyProxy < Rails::Railtie
      require "active_record_proxy_adapters/connection_handling/trilogy_proxy"
    end
  end
end
