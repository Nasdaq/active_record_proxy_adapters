# frozen_string_literal: true

module ActiveRecordProxyAdapters
  module Contextualizer # rubocop:disable Style/Documentation
    module_function

    # @return [ActiveRecordProxyAdapters::Context]
    # Retrieves the current context for the thread.
    def current_context
      Thread.current.thread_variable_get(:arpa_context)
    end

    # @param context [ActiveRecordProxyAdapters::Context]
    # Sets the current context for the thread.
    def current_context=(context)
      Thread.current.thread_variable_set(:arpa_context, context)
    end
  end
end
