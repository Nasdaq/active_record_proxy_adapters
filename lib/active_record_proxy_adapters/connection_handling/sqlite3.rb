# frozen_string_literal: true

begin
  require "active_record/connection_adapters/sqlite3_proxy_adapter"
rescue LoadError
  # sqlite3 not available
  return
end

module ActiveRecordProxyAdapters
  module SQLite3
    # Module to extend ActiveRecord::Base with the connection handling methods.
    # Required to make adapter work in ActiveRecord versions <= 7.2.x
    module ConnectionHandling
      def sqlite3_proxy_adapter_class
        ActiveRecord::ConnectionAdapters::SQLite3ProxyAdapter
      end

      def sqlite3_proxy_connection(config)
        connection_factory_mapping
          .fetch("#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}")
          .call(config)
      end

      def connection_factory_mapping
        {
          "7.0" => ->(config) { sqlite3_proxy_connection_ar_v70(config) },
          "7.1" => ->(config) { sqlite3_proxy_connection_ar_v71(config) }
        }
      end

      def sqlite3_proxy_connection_ar_v70(config) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength
        config = config.symbolize_keys

        # Require database.
        raise ArgumentError, "No database file specified. Missing argument: database" unless config[:database]

        # Allow database path relative to Rails.root, but only if the database
        # path is not the special path that tells sqlite to build a database only
        # in memory.
        if ":memory:" != config[:database] && !config[:database].to_s.start_with?("file:")
          config[:database] = File.expand_path(config[:database], Rails.root) if defined?(Rails.root)
          dirname = File.dirname(config[:database])
          Dir.mkdir(dirname) unless File.directory?(dirname)
        end

        db = ::SQLite3::Database.new(
          config[:database].to_s,
          config.merge(results_as_hash: true)
        )

        sqlite3_proxy_adapter_class.new(db, logger, nil, config)
      rescue Errno::ENOENT => e
        raise ActiveRecord::NoDatabaseError if e.message.include?("No such file or directory")

        raise
      end

      def sqlite3_proxy_connection_ar_v71(config)
        sqlite3_proxy_adapter_class.new(config)
      end
    end
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Base.extend(ActiveRecordProxyAdapters::SQLite3::ConnectionHandling)
end
