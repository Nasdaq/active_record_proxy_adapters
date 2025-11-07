# frozen_string_literal: true

require "active_record_proxy_adapters/rake"

RSpec.describe ActiveRecordProxyAdapters::Rake do
  let(:fake_rake_tasks_path) { File.join(__dir__, "mock_tasks.rake") }
  let(:fake_db_task) { Rake::Task["db:fake_migrate"] }

  before do
    allow(described_class).to receive(:rake_tasks_path).and_return(fake_rake_tasks_path)
    Rake::Task.clear
  end

  after do
    fake_db_task.reenable
  end

  describe ".load_tasks" do
    subject(:load_tasks) { described_class.load_tasks }

    it "loads rake tasks without error" do
      load_tasks

      expect(Rake::Task.task_defined?("db:fake_migrate")).to be(true)
    end
  end

  describe ".enhance_db_tasks" do
    subject(:enhance_db_tasks) { described_class.enhance_db_tasks }

    before do
      described_class.load_tasks
    end

    it "enhances db tasks to push and pop connection stack" do # rubocop:disable RSpec/ExampleLength
      enhance_db_tasks

      expect do
        fake_db_task.invoke
      end.to output(<<~OUTPUT).to_stdout
        Fake environment loaded
        Pushed to stack
        Mock db:migrate task executed
        Popped from stack
      OUTPUT
    end

    it "reenables the push to stack task for subsequent invocations" do
      enhance_db_tasks

      fake_db_task.invoke

      expect(Rake::Task["arpa:push_to_stack"].already_invoked).to be(false)
    end

    it "reenables the pop from stack task for subsequent invocations" do
      enhance_db_tasks

      fake_db_task.invoke

      expect(Rake::Task["arpa:pop_from_stack"].already_invoked).to be(false)
    end
  end
end
