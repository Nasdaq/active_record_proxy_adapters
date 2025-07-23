# frozen_string_literal: true

module ActiveRecordProxyAdapters
  class LogSubscriber < ActiveRecord::LogSubscriber # rubocop:disable Style/Documentation
    include Mixin::Configuration

    attach_to :active_record

    IGNORE_PAYLOAD_NAMES = %w[SCHEMA EXPLAIN].freeze

    def sql(event)
      payload = event.payload
      name = payload[:name]
      unless IGNORE_PAYLOAD_NAMES.include?(name)
        name = [database_instance_prefix_for(event), name].compact.join(" ")
        payload[:name] = name
      end
      super
    end

    protected

    def database_instance_prefix_for(event)
      connection      = event.payload[:connection]
      db_config       = connection.pool.try(:db_config) || NullConfig.new # AR 7.0.x does not support "NullConfig"
      connection_name = db_config.name

      prefix = if db_config.replica?
                 log_subscriber_replica_prefix(connection_name)
               else
                 log_subscriber_primary_prefix(connection_name)
               end

      "[#{prefix.call(event)}]"
    end

    class NullConfig # rubocop:disable Style/Documentation
      def method_missing(...)
        nil
      end

      def respond_to_missing?(*)
        true
      end
    end
  end
end
