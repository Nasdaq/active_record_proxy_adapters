# frozen_string_literal: true

require "active_record_proxy_adapters/connection_handling/postgresql"
require "active_record_proxy_adapters/connection_handling/mysql2"

module ActiveRecordProxyAdapters
  # Module to extend ActiveRecord::Base with the connection handling methods.
  # Required to make adapter work in ActiveRecord versions <= 7.2.x
  module ConnectionHandling
  end
end
