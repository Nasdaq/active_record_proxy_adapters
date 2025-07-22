# frozen_string_literal: true

require "active_record_proxy_adapters/mixin/configuration"

module ActiveRecordProxyAdapters
  # Context is a simple class that holds a registry of connection names and their last write timestamps.
  # It is used to track the last time a write operation was performed on each connection.
  # This allows the proxy to determine whether to route read requests to the primary or replica database
  class Context
    include Mixin::Configuration

    # @param hash [Hash] A hash containing the connection names as keys and the last write timestamps as values.
    #   Can be empty.
    def initialize(hash)
      @timestamp_registry = hash.transform_values(&:to_f)
    end

    def recent_write_to_primary?(connection_name)
      now - self[connection_name] < proxy_delay
    end

    def update_for(connection_name)
      self[connection_name] = now
    end

    def [](connection_name)
      timestamp_registry[connection_name] || 0
    end

    def []=(connection_name, timestamp)
      timestamp_registry[connection_name] = timestamp
    end

    def to_h
      timestamp_registry.dup
    end

    private

    attr_reader :timestamp_registry

    def now
      Time.now.utc.to_f
    end
  end
end
