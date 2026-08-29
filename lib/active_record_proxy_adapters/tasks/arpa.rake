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

    depth = Thread.current.thread_variable_get(:arpa_rake_stack_depth).to_i
    Thread.current.thread_variable_set(:arpa_rake_stack_depth, depth + 1)
  end

  desc "Pops from connected_to stack after rake task is invoked"
  task :pop_from_stack do
    depth = Thread.current.thread_variable_get(:arpa_rake_stack_depth).to_i
    if depth.positive?
      ActiveRecord::Base.connected_to_stack.pop
      Thread.current.thread_variable_set(:arpa_rake_stack_depth, depth == 1 ? nil : depth - 1)
    end
  end
end
