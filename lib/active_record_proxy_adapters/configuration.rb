# frozen_string_literal: true

require "active_record_proxy_adapters/cache_configuration"
require "active_record_proxy_adapters/context"
require "active_record_proxy_adapters/database_configuration"
require "active_record_proxy_adapters/errors"
require "active_record_proxy_adapters/synchronizable_configuration"
require "active_support/core_ext/integer/time"
require "logger"

module ActiveRecordProxyAdapters
  # Provides a global configuration object to configure how the proxy should behave.
  class Configuration
    include SynchronizableConfiguration

    DEFAULT_DATABASE_NAME         = :primary
    DEFAULT_REPLICA_DATABASE_NAME = :primary_replica
    TIMEOUT_MESSAGE_BUILDER = proc { |sql_string, regex = nil|
      [regex, "timed out. Input too big (#{sql_string.size})."].compact_blank.join(" ")
    }.freeze

    private_constant :TIMEOUT_MESSAGE_BUILDER

    REGEXP_TIMEOUT_STRATEGY_REGISTRY = {
      log: proc { |sql_string, regex = nil|
        ActiveRecordProxyAdapters.config.logger.error(TIMEOUT_MESSAGE_BUILDER.call(sql_string, regex))
      },
      raise: proc { |sql_string, regex = nil|
        raise ActiveRecordProxyAdapters::RegexpTimeoutError, TIMEOUT_MESSAGE_BUILDER.call(sql_string, regex)
      }
    }.freeze

    # @return [Class] The context that is used to store the current request's state.
    attr_reader :context_store

    # @return [Proc] The timeout strategy to use for regex matching.
    attr_reader :regexp_timeout_strategy

    # @return [Logger] The logger to use for logging messages.
    attr_reader :logger

    def initialize
      @lock = Monitor.new

      self.cache_configuration     = CacheConfiguration.new(@lock)
      self.context_store           = ActiveRecordProxyAdapters::Context
      self.regexp_timeout_strategy = :log
      self.logger                  = ActiveRecord::Base.logger || Logger.new($stdout)
      @database_configurations     = {}
    end

    def log_subscriber_primary_prefix=(prefix)
      default_database_config.log_subscriber_prefix = prefix
    end

    def log_subscriber_primary_prefix
      default_database_config.log_subscriber_prefix
    end

    def log_subscriber_replica_prefix=(prefix)
      default_replica_config.log_subscriber_prefix = prefix
    end

    def log_subscriber_replica_prefix
      default_replica_config.log_subscriber_prefix
    end

    def proxy_delay
      default_database_config.proxy_delay
    end

    def proxy_delay=(proxy_delay)
      default_database_config.proxy_delay = proxy_delay
    end

    def checkout_timeout
      default_database_config.checkout_timeout
    end

    def checkout_timeout=(checkout_timeout)
      default_database_config.checkout_timeout = checkout_timeout
    end

    def logger=(logger)
      synchronize_update(:logger, from: @logger, to: logger) do
        @logger = logger
      end
    end

    def regexp_timeout_strategy=(strategy)
      synchronize_update(:regexp_timeout_strategy, from: @regexp_timeout_strategy, to: strategy) do
        @regexp_timeout_strategy = if strategy.respond_to?(:call)
                                     strategy
                                   else
                                     REGEXP_TIMEOUT_STRATEGY_REGISTRY.fetch(strategy)
                                   end
      rescue KeyError
        raise ActiveRecordProxyAdapters::ConfigurationError,
              "Invalid regex timeout strategy: #{strategy.inspect}. Must be one of: #{valid_regexp_timeout_strategies}"
      end
    end

    def database(database_name)
      key = database_name.to_s
      lock.synchronize { @database_configurations[key] ||= DatabaseConfiguration.new }

      block_given? ? yield(database_configurations[key]) : database_configurations[key]
    end

    def cache
      block_given? ? yield(cache_configuration) : cache_configuration
    end

    private

    attr_reader :cache_configuration, :database_configurations, :lock

    def valid_regexp_timeout_strategies
      REGEXP_TIMEOUT_STRATEGY_REGISTRY.keys
    end

    def default_database_config
      database(DEFAULT_DATABASE_NAME)
    end

    def default_replica_config
      database(DEFAULT_REPLICA_DATABASE_NAME)
    end

    def cache_configuration=(cache_configuration)
      synchronize_update(:cache_configuration, from: @cache_configuration, to: cache_configuration) do
        @cache_configuration = cache_configuration
      end
    end

    def context_store=(context_store)
      synchronize_update(:context_store, from: @context_store, to: context_store) do
        @context_store = context_store
      end
    end
  end
end
