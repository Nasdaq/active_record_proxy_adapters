# frozen_string_literal: true

require "active_support"
require "active_record_proxy_adapters/middleware"

module ActiveRecordProxyAdapters
  # Hooks into rails boot process to add the rack middleware for stickiness cookies.
  class RackMiddleware < Rails::Railtie
    initializer "active_record_proxy_adapters.add_middleware_to_rack_stack" do |app|
      app.middleware.use ActiveRecordProxyAdapters::Middleware
      app.middleware.use Rack::Events, [ActiveRecordProxyAdapters::Middleware::EventHandler.new]
    end
  end
end
