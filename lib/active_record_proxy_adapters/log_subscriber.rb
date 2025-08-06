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
      db_config       = connection.pool.try(:db_config)
      connection_name = db_config.name

      prefix = log_subscriber_prefix(connection_name)

      "[#{prefix.call(event)}]"
    end
  end
end
