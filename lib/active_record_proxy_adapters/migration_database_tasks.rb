# frozen_string_literal: true

module ActiveRecordProxyAdapters
  # This mixin ensures that migration-related database tasks stick to the primary database to avoid conflicts between
  # this gem and other gems that might extend ActiveRecord.
  module MigrationDatabaseTasks
    def migrate(...)
      sticking_to_primary { super }
    end

    def migrate_status(...)
      sticking_to_primary { super }
    end

    private

    def sticking_to_primary(&)
      ActiveRecord::Base.connected_to(role: arpa_context.writing_role, &)
    end

    def arpa_context
      ActiveRecordProxyAdapters::ActiveRecordContext.new
    end
  end

  # This mixin ensures that database forward / rollback, up and down tasks stick to the primary database to avoid
  # conflicts between this gem and other gems that might extend ActiveRecord.
  module MigrationContext
    def forward(...)
      sticking_to_primary { super }
    end

    def rollback(...)
      sticking_to_primary { super }
    end

    def run(...)
      sticking_to_primary { super }
    end

    def sticking_to_primary(&)
      ActiveRecord::Base.connected_to(role: arpa_context.writing_role, &)
    end

    def arpa_context
      ActiveRecordProxyAdapters::ActiveRecordContext.new
    end
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Tasks::DatabaseTasks.prepend(ActiveRecordProxyAdapters::MigrationDatabaseTasks)
  ActiveRecord::MigrationContext.prepend(ActiveRecordProxyAdapters::MigrationContext)
end
