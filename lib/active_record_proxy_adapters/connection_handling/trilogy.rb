# frozen_string_literal: true

begin
  require "active_record/connection_adapters/trilogy_proxy_adapter"
rescue LoadError
  # trilogy not available
  return
end

module ActiveRecordProxyAdapters
  module Trilogy
    # Module to extend ActiveRecord::Base with the connection handling methods.
    # Required to make adapter work in ActiveRecord versions <= 7.2.x
    module ConnectionHandling
      def trilogy_proxy_adapter_class
        ActiveRecord::ConnectionAdapters::TrilogyProxyAdapter
      end

      def trilogy_proxy_connection(config) # rubocop:disable Metrics/MethodLength
        configuration = config.dup

        # Set FOUND_ROWS capability on the connection so UPDATE queries returns number of rows
        # matched rather than number of rows updated.
        configuration[:found_rows] = true

        options = [
          configuration[:host],
          configuration[:port],
          configuration[:database],
          configuration[:username],
          configuration[:password],
          configuration[:socket],
          0
        ]

        trilogy_proxy_adapter_class.new nil, logger, options, configuration
      end
    end
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Base.extend(ActiveRecordProxyAdapters::Trilogy::ConnectionHandling)
end
