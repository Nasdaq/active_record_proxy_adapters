# frozen_string_literal: true

module ActiveRecordProxyAdapters
  module DatabaseTasks # rubocop:disable Style/Documentation
    extend ActiveSupport::Concern

    included do
      def create(...)
        sticking_to_primary { super }
      end

      def drop(...)
        sticking_to_primary { super }
      end

      def structure_dump(...)
        sticking_to_primary { super }
      end

      def structure_load(...)
        sticking_to_primary { super }
      end

      def purge(...)
        sticking_to_primary { super }
      end

      private

      def sticking_to_primary(&)
        ActiveRecord::Base.connected_to(role: context.writing_role, &)
      end

      def context
        ActiveRecordProxyAdapters::ActiveRecordContext.new
      end
    end
  end
end
