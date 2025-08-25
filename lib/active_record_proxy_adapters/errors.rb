# frozen_string_literal: true

module ActiveRecordProxyAdapters
  Error              = Class.new(StandardError)
  RegexpTimeoutError = Class.new(Error)
  ConfigurationError = Class.new(Error)
end
