# frozen_string_literal: true

require "rake"

module ActiveRecordProxyAdapters
  # Enhances all rails db rake tasks to stick to writer connection
  module Rake
    module_function

    def load_tasks
      Dir[rake_tasks_path].each { |rake_path| load(rake_path) }
    end

    def rake_tasks_path
      File.join(__dir__, "tasks/**/*.rake")
    end

    def enhance_db_tasks
      ::Rake::Task
        .tasks
        .select(&enhanceable_db_task?)
        .each { |task| task.enhance([push_to_stack_rake_task.name], &pop_from_stack_and_reenable) }
    end

    def push_to_stack_rake_task
      ::Rake::Task["arpa:push_to_stack"]
    end

    def pop_from_stack_rake_task
      ::Rake::Task["arpa:pop_from_stack"]
    end

    def pop_from_stack_and_reenable
      proc do
        pop_from_stack_rake_task.invoke
        [push_to_stack_rake_task, pop_from_stack_rake_task].each(&:reenable)
      end
    end

    def enhanceable_db_task?
      proc do |task|
        task_name = task.name
        task_name.start_with?("db:") && task_name != "db:load_config"
      end
    end
  end
end
