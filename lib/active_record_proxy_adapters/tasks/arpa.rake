# frozen_string_literal: true

namespace :arpa do
  desc "Pushes to connected_to stack before rake task is executed"
  task :push_to_stack do
    writing_role = ActiveRecordProxyAdapters::ActiveRecordContext.writing_role

    ActiveRecord::Base.connected_to_stack << {
      role: writing_role,
      shard: nil,
      prevent_writes: false,
      klasses: [ActiveRecord::Base]
    }

    Thread.current.thread_variable_set(:arpa_rake_pushed_to_stack, true)
  end

  desc "Pops from connected_to stack after rake task is invoked"
  task :pop_from_stack do
    if Thread.current.thread_variable_get(:arpa_rake_pushed_to_stack)
      ActiveRecord::Base.connected_to_stack.pop
      Thread.current.thread_variable_set(:arpa_rake_pushed_to_stack, nil)
    end
  end
end
