# frozen_string_literal: true

module ActiveRecordProxyAdapters
  # A mixin for managing the context of current database connections.
  module Contextualizer
    module_function

    # @return [ActiveRecordProxyAdapters::Context]
    # Retrieves the context for the current thread.
    def current_context
      Thread.current.thread_variable_get(:arpa_context)
    end

    # @param context [ActiveRecordProxyAdapters::Context]
    # Sets the context for the current thread.
    def current_context=(context)
      Thread.current.thread_variable_set(:arpa_context, context)
    end
  end
end
