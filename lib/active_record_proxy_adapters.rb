# frozen_string_literal: true

# The gem namespace.
module ActiveRecordProxyAdapters
end

require_relative "active_record_proxy_adapters/railtie" if defined?(Rails::Railtie)
