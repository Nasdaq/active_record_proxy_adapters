# frozen_string_literal: true

module ActiveRecordProxyAdapters
  # Collection of helpers to handle common active record methods that are defined in different places in different
  # versions of rails.
  class ActiveRecordContext
    delegate :reading_role, :reading_role=, :writing_role, :writing_role=, to: :ActiveRecord
    delegate :version, to: :ActiveRecord, prefix: :active_record

    class << self
      delegate_missing_to :new
    end

    def connection_class_for(connection)
      return connection.connection_descriptor.name.constantize if active_record_v8_0_2_or_greater?

      connection.connection_class || ActiveRecord::Base
    end

    def hijackable_methods
      hijackable = %i[execute exec_query]

      hijackable << :internal_exec_query if active_record_v7_1_or_greater?

      hijackable
    end

    def active_record_v7?
      active_record_version >= Gem::Version.new("7.1") && active_record_version < Gem::Version.new("8.0")
    end

    def active_record_v7_1_or_greater?
      active_record_version >= Gem::Version.new("7.1")
    end

    def active_record_v7_2_or_greater?
      active_record_version >= Gem::Version.new("7.2")
    end

    def active_record_v8_0_or_greater?
      active_record_version >= Gem::Version.new("8.0")
    end

    def active_record_v8_0_2_or_greater?
      active_record_version >= Gem::Version.new("8.0.2")
    end
  end
end
