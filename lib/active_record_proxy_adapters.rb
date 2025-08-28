# frozen_string_literal: true

require "active_record"
require "active_record_proxy_adapters/version"
require "active_record_proxy_adapters/configuration"

# The gem namespace.
module ActiveRecordProxyAdapters
end

require_relative "active_record_proxy_adapters/railtie" if defined?(Rails::Railtie)
