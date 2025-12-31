# frozen_string_literal: true

RSpec.shared_context "a proxied model setup" do # rubocop:disable RSpec/ContextWording
  attr_reader :log_file

  def latest_log_output
    log_string.lines.last&.chomp
  end

  def log_string
    log_file.string
  end

  def proxy_delay
    2.seconds
  end

  def log_subscriber_primary_prefix
    "#{database_identifier}_primary"
  end

  def log_subscriber_replica_prefix
    "#{database_identifier}_replica"
  end

  let(:model_class)         { nil }
  let(:database_identifier) { nil }
  let(:truncate_database)   { nil }

  let(:user_model_class) do
    Class.new(model_class) do
      self.table_name = "users"
    end
  end

  before { stub_const("TestUser", user_model_class) }

  around do |example|
    truncate_database

    @log_file = StringIO.new
    logger = Logger.new(log_file, level: :debug)
    logger.formatter = proc do |_severity, datetime, _progname, msg|
      formatted_time = datetime.strftime("%Y-%m-%d %H:%M:%S")
      "#{formatted_time} - #{msg}\n"
    end

    logger_original = ActiveRecord::Base.logger
    ActiveRecord::Base.logger = logger
    ActiveRecordProxyAdapters.configure do |config|
      config.logger = logger

      config.database(:"#{database_identifier}_primary") do |db_config|
        db_config.proxy_delay = proxy_delay
        db_config.log_subscriber_prefix = log_subscriber_primary_prefix
      end

      config.database(:"#{database_identifier}_replica") do |db_config|
        db_config.log_subscriber_prefix = log_subscriber_replica_prefix
      end
    end

    example.run

    ActiveRecord::Base.logger = logger_original
  end
end

RSpec.shared_examples_for "a write instance method" do |method_name|
  subject(:run_test!) { user.public_send(method_name) }

  let(:user) { TestUser.new(name: "Jane Doe", email: "jane.doe@example.com") }
  let(:read_query) { TestUser.exists? }

  before do
    Timecop.travel((proxy_delay + 1.second).ago) { user }
  end

  it "sticks to the primary pool" do
    run_test!

    expect(latest_log_output).to include("[#{log_subscriber_primary_prefix}]")
  end

  context "when within the proxy delay period", :freeze_time do
    it "sticks to the primary for reads after a write" do
      run_test!
      read_query

      expect(latest_log_output).to include("[#{log_subscriber_primary_prefix}]")
    end
  end

  context "when out of the proxy delay period", :freeze_time do
    it "resumes connecting to replica after the proxy delay" do
      run_test!
      Timecop.travel((proxy_delay + 1.second).from_now) { read_query }

      expect(latest_log_output).to include("[#{log_subscriber_replica_prefix}]")
    end
  end
end

RSpec.shared_examples_for "a write class method" do |method_name|
  subject(:run_test!) { TestUser.public_send(method_name) }

  let(:read_query) { TestUser.exists? }

  it "sticks to the primary pool" do
    run_test!

    expect(latest_log_output).to include("[#{log_subscriber_primary_prefix}]")
  end

  it "sticks to the primary for reads after a write" do
    run_test!

    read_query

    expect(latest_log_output).to include("[#{log_subscriber_primary_prefix}]")
  end

  it "resumes connecting to replica after the proxy delay" do
    Timecop.freeze(proxy_delay.from_now + 1.0.second) do
      read_query

      expect(latest_log_output).to include("[#{log_subscriber_replica_prefix}]")
    end
  end
end

RSpec.shared_examples_for "a read instance method" do |method_name|
  subject(:run_test!) { user.public_send(method_name) }

  let(:user) { TestUser.create!(name: "Jane Doe", email: "jane.doe@example.com") }

  context "when within the proxy delay period", :freeze_time do
    it "sticks to the primary pool" do
      user

      run_test!

      expect(latest_log_output).to include("[#{log_subscriber_primary_prefix}]")
    end
  end

  context "when out of the proxy delay period" do
    before do
      Timecop.freeze(proxy_delay.ago - 1.second) { user }
    end

    it "reroutes query to the replica pool" do
      run_test!

      expect(latest_log_output).to include("[#{log_subscriber_replica_prefix}]")
    end

    context "when inside a transaction" do
      it "sticks to the primary pool" do
        TestUser.transaction do
          run_test!

          expect(latest_log_output).to include("[#{log_subscriber_primary_prefix}]")
        end
      end
    end
  end
end

RSpec.shared_examples_for "a proxied model" do
  include_context "a proxied model setup"

  describe "ActiveRecord::Relation methods" do
    describe ".all" do
      subject(:all) { TestUser.all }

      it "reroutes query to the replica pool" do
        all.to_a

        expect(latest_log_output).to include("[#{log_subscriber_replica_prefix}]")
      end
    end
  end

  describe ".create" do
    it_behaves_like "a write class method", :create do
      subject(:run_test!) { TestUser.create(name: "Jane Doe", email: "jane.doe@example.com") }
    end
  end

  describe ".create!" do
    it_behaves_like "a write class method", :create! do
      subject(:run_test!) { TestUser.create!(name: "Jane Doe", email: "jane.doe@example.com") }
    end
  end

  describe ".insert" do
    it_behaves_like "a write class method", :insert do
      subject(:run_test!) { TestUser.insert({ name: "Jane Doe", email: "jane.doe@example.com" }) }
    end
  end

  describe ".insert!" do
    it_behaves_like "a write class method", :insert! do
      subject(:run_test!) { TestUser.insert!({ name: "Jane Doe", email: "jane.doe@example.com" }) }
    end
  end

  describe "#reload" do
    it_behaves_like "a read instance method", :reload
  end

  describe "#save" do
    it_behaves_like "a write instance method", :save
  end

  describe "#save!" do
    it_behaves_like "a write instance method", :save!
  end

  describe "#update" do
    it_behaves_like "a write instance method", :update do
      subject(:run_test!) { user.update(name: "Janet Doe", email: "janet.doe@example.com") }

      let(:user) { TestUser.create!(name: "Jane Doe", email: "jane.doe@example.com") }
      let(:read_query) { user.reload }
    end
  end

  describe "#update!" do
    it_behaves_like "a write instance method", :update! do
      subject(:run_test!) { user.update!(name: "Janet Doe", email: "janet.doe@example.com") }

      let(:user) { TestUser.create!(name: "Jane Doe", email: "jane.doe@example.com") }
      let(:read_query) { user.reload }
    end
  end

  describe "#touch" do
    it_behaves_like "a write instance method", :touch do
      let(:user) { TestUser.create!(name: "Jane Doe", email: "jane.doe@example.com") }
    end
  end

  describe "#increment!" do
    it_behaves_like "a write instance method", :increment! do
      subject(:run_test!) { user.increment!(:age) }

      let(:user) { TestUser.create!(name: "Jane Doe", email: "jane.doe@example.com") }
    end
  end

  describe "#decrement!" do
    it_behaves_like "a write instance method", :decrement! do
      subject(:run_test!) { user.decrement!(:age) }

      let(:user) { TestUser.create!(name: "Jane Doe", email: "jane.doe@example.com") }
    end
  end

  describe "#update_columns" do
    it_behaves_like "a write instance method", :update_columns do
      subject(:run_test!) { user.update_columns(name: "Janet Doe", email: "janet.doe@example.com") }

      let(:user) { TestUser.create!(name: "Jane Doe", email: "jane.doe@example.com") }
    end
  end

  describe "#destroy" do
    it_behaves_like "a write instance method", :destroy do
      let(:user) { TestUser.create!(name: "Jane Doe", email: "jane.doe@example.com") }
    end
  end

  describe "#destroy!" do
    it_behaves_like "a write instance method", :destroy! do
      let(:user) { TestUser.create!(name: "Jane Doe", email: "jane.doe@example.com") }
    end
  end

  describe "#delete" do
    it_behaves_like "a write instance method", :delete do
      let(:user) { TestUser.create!(name: "Jane Doe", email: "jane.doe@example.com") }
    end
  end
end
