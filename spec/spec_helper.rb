# frozen_string_literal: true

require "simplecov"
require "simplecov_json_formatter"
require "active_support/core_ext/object/blank"

simple_cov_formatters = [SimpleCov::Formatter::JSONFormatter]
simple_cov_formatters << SimpleCov::Formatter::HTMLFormatter unless ENV["CI"]

SimpleCov.start do
  self.formatters = simple_cov_formatters
  add_filter "/spec/"
  add_group "PostgreSQL" do |src_file|
    [/postgresql/, /postgre_sql/].any? { |pattern| pattern.match?(src_file.filename) }
  end

  sanitize      = ->(filename) { filename.tr(".", "_").tr("~>", "").strip }
  ruby_version  = sanitize.call(ENV.fetch("RUBY_VERSION", ""))
  ar_version    = sanitize.call(ENV.fetch("RAILS_VERSION", ""))
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
require "active_record_proxy_adapters/log_subscriber"
require_relative "test_helper"

ActiveRecord::Base.extend ActiveRecordProxyAdapters::ConnectionHandling
ActiveRecord::Base.logger = Logger.new(Tempfile.create)

ENV["RAILS_ENV"] ||= TestHelper.env_name

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:suite) { TestHelper.setup_active_record_config }

  wrap_test_case_in_transaction = proc do |example|
    connection = ActiveRecord::Base.connection

    connection.execute_unproxied("BEGIN -- opening test wrapper transaction")

    example.run

    connection.execute_unproxied("ROLLBACK -- rolling back test wrapper transaction")
  end

  config.around(:each, :transactional, &wrap_test_case_in_transaction)
end
