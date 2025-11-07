# frozen_string_literal: true

task :fake_environment do
  $stdout.puts "Fake environment loaded"
end

namespace :arpa do
  task :push_to_stack do
    $stdout.puts "Pushed to stack"
    Thread.current.thread_variable_set(:arpa_rake_pushed_to_stack, true)
  end

  task :pop_from_stack do
    if Thread.current.thread_variable_get(:arpa_rake_pushed_to_stack)
      $stdout.puts "Popped from stack"
      Thread.current.thread_variable_set(:arpa_rake_pushed_to_stack, nil)
    end
  end
end

namespace :db do
  desc "Mock task for testing"
  task fake_migrate: :fake_environment do
    puts "Mock db:migrate task executed"
  end
end
