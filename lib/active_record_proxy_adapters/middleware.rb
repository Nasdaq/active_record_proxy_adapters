# frozen_string_literal: true

require "rack"
require "json"
require "active_record_proxy_adapters/context"
require "active_record_proxy_adapters/contextualizer"
require "active_record_proxy_adapters/mixin/configuration"

module ActiveRecordProxyAdapters
  class Middleware # rubocop:disable Style/Documentation
    include Contextualizer
    include Mixin::Configuration

    COOKIE_NAME   = "arpa_context"
    COOKIE_BUFFER = 5.seconds.freeze
    DEFAULT_COOKIE_OPTIONS = {
      path: "/",
      http_only: true
    }.freeze

    class << self
      include Mixin::Configuration
    end

    COOKIE_READER = lambda do |rack_env|
      rack_request = Rack::Request.new(rack_env)
      arpa_cookie  = rack_request.cookies[COOKIE_NAME]
      JSON.parse(arpa_cookie || "{}")
    rescue JSON::ParserError
      {}
    end.freeze

    COOKIE_WRITER = lambda do |headers, cookie_hash, options|
      cookie           = DEFAULT_COOKIE_OPTIONS.merge(options)
      max_value        = cookie_hash.values.max || 0
      then_time        = Time.at(max_value).utc
      expires          = then_time + proxy_delay + COOKIE_BUFFER
      max_age          = expires - then_time
      cookie[:expires] = expires
      cookie[:max_age] = max_age
      cookie[:value]   = cookie_hash.to_json

      Rack::Utils.set_cookie_header!(headers, COOKIE_NAME, cookie)
    end.freeze

    def initialize(app, cookie_options = {})
      @app = app
      @cookie_options = cookie_options
    end

    def call(env)
      return @app.call(env) if ignore_request?(env)

      self.current_context = context_store.new(COOKIE_READER.call(env))

      status, headers, body = @app.call(env)

      update_cookie_from_context(headers)

      [status, headers, body]
    end

    private

    def update_cookie_from_context(headers)
      COOKIE_WRITER.call(headers, current_context.to_h, @cookie_options)
    end

    def ignore_request?(env)
      return false unless defined?(Rails)
      return false unless asset_prefix

      /^#{asset_prefix}/.match?(env["PATH_INFO"].to_s)
    end

    def asset_prefix
      Rails.try(:application).try(:config).try(:assets).try(:prefix)
    end
  end
end
