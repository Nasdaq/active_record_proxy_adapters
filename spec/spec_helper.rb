# frozen_string_literal: true

require "simplecov"
require "simplecov_json_formatter"
require "active_support/core_ext/object/blank"
require "simple_cov_groups"
require "active_record"
require "active_support/testing/time_helpers"

simple_cov_formatters = [SimpleCov::Formatter::JSONFormatter]
simple_cov_formatters << SimpleCov::Formatter::HTMLFormatter unless ENV["CI"]

SimpleCov.start do
  self.formatters = simple_cov_formatters
  add_filter "/spec/"
  SIMPLE_COV_GROUPS.call

  sanitize      = ->(filename) { filename.tr(".", "_").tr("~>", "").strip }
  ruby_version  = sanitize.call(RUBY_VERSION)
  ar_version    = sanitize.call(ActiveRecord.version.to_s)
  coverage_path = [
    "ruby",
    ruby_version,
    "ar",
    ar_version
  ].reject(&:blank?).join("-")

  coverage_dir "coverage/#{coverage_path}"
  command_name "Ruby-#{ruby_version}-AR-#{ar_version}"
end

require "active_record_proxy_adapters"

require "active_record_proxy_adapters/connection_handling"
ActiveSupport.on_load(:active_record) do
  require "active_record_proxy_adapters/log_subscriber"
end

adapter_loaded = proc { |adapter| $stdout.puts "#{adapter} loaded" }
ActiveSupport.on_load(:active_record_postgresqlproxyadapter, &adapter_loaded)
ActiveSupport.on_load(:active_record_mysql2proxyadapter, &adapter_loaded)
ActiveSupport.on_load(:active_record_trilogyproxyadapter, &adapter_loaded)
ActiveSupport.on_load(:active_record_sqlite3proxyadapter, &adapter_loaded)

require_relative "test_helper"

ActiveRecord::Base.logger = Logger.new(Tempfile.create)

ENV["RAILS_ENV"] ||= TestHelper.env_name

RSpec.configure do |config|
  proxy_config                         = ActiveRecordProxyAdapters.config
  proxy_config.logger                  = ActiveRecord::Base.logger
  proxy_config.regexp_timeout_strategy = :log

  config.include(ActiveSupport::Testing::TimeHelpers)
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:suite) do
    ActiveSupport.on_load(:active_record) { TestHelper.setup_active_record_config }
  end

  config.before do
    ActiveRecordProxyAdapters::Contextualizer.current_context = proxy_config.context_store.new({})
  end

  wrap_test_case_in_transaction = proc do |example|
    connection = ActiveRecord::Base.connection

    connection.execute_unproxied("BEGIN -- opening test wrapper transaction")

    example.run

    connection.execute_unproxied("ROLLBACK -- rolling back test wrapper transaction")
  end

  config.around(:each, :transactional, &wrap_test_case_in_transaction)

  RSpec::Matchers.define_negated_matcher :not_change, :change
end
