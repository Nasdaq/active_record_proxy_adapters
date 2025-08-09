# frozen_string_literal: true

module ActiveRecordProxyAdapters
  module SynchronizableConfiguration # rubocop:disable Style/Documentation
    extend ActiveSupport::Concern

    included do
      private

      def synchronize_update(attribute, from:, to:, &block)
        ActiveSupport::Notifications.instrument(
          "active_record_proxy_adapters.configuration_update",
          attribute:,
          who: Thread.current,
          from:,
          to:
        ) do
          lock.synchronize(&block)
        end
      end
    end
  end
end
