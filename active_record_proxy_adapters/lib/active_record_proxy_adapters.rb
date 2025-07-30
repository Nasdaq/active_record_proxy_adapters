# frozen_string_literal: true

require "active_record"
require "active_record_proxy_adapters/version"
require "active_record_proxy_adapters/configuration"

# The gem namespace.
module ActiveRecordProxyAdapters
  class Error < StandardError; end

  module_function

  def configure
    yield(config)
  end

  def bust_query_cache
    config.cache.bust
  end

  def config
    @config ||= Configuration.new
  end
end

require_relative "active_record_proxy_adapters/railtie" if defined?(Rails::Railtie)
