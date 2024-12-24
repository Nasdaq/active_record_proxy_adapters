# frozen_string_literal: true

module ActiveRecordProxyAdapters
  class LogSubscriber < ActiveRecord::LogSubscriber # rubocop:disable Style/Documentation
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
      connection = event.payload[:connection]
      config = connection.instance_variable_get(:@config)
      prefix = if config[:replica] || config["replica"]
                 log_subscriber_replica_prefix
               else
                 log_subscriber_primary_prefix
               end

      "[#{prefix.call(event)}]"
    end

    private

    delegate :log_subscriber_primary_prefix, :log_subscriber_replica_prefix, to: :config

    def config
      ActiveRecordProxyAdapters.config
    end
  end
end
