# frozen_string_literal: true

require "active_record_proxy_adapters/middleware"
require "cgi"

RSpec.describe ActiveRecordProxyAdapters::Middleware do
  def to_cookie_string(cookie_hash)
    "#{cookie_name}=#{CGI.escape(cookie_hash.to_json)}; path=/; max-age=1"
  end

  def from_cookie_string(cookie_string)
    cookie_properties = cookie_string.split(";").map(&:strip)
    cookie_properties.each_with_object({}) do |property, cookie_hash|
      key, value = property.split("=")

      if key == "arpa_context"
        cookie_hash["name"] = key
        cookie_hash["value"] = JSON.parse(CGI.unescape(value))
      else
        cookie_hash[key] = value || true # cookie property without a value is treated as true
      end
    end
  end

  let(:user_model) do
    Class.new(TestHelper::SQLite3Record) do
      self.table_name = "users"
    end
  end

  describe "#call", freeze_time: { to: Time.utc(2026) } do
    let(:middleware) { described_class.new(app, {}) }

    let(:app) do
      ->(env) { [200, {}, env[:query] || query] }
    end
    let(:query) { User.limit(1).to_a }
    let(:cookie_name) { described_class::COOKIE_NAME }

    before do
      stub_const("User", user_model)

      ActiveRecordProxyAdapters.configure do |config|
        config.proxy_delay      = 2.seconds
        config.checkout_timeout = 2.seconds
      end
    end

    context "when context cookie is not set" do
      it "initializes the cookie with an empty hash" do
        env = {}
        _, headers, = middleware.call(env)

        expect(headers["Set-Cookie"]).to include("arpa_context=#{CGI.escape("{}")}")
      end
    end

    context "when context cookie is set" do
      it "keeps cookie value from previous request" do
        cookie_timestamp = Time.current.utc.to_f # 2025-01-01 00:00:00 UTC
        cookie_hash      = { "sqlite3_primary" => cookie_timestamp }
        env              = { "HTTP_COOKIE" => to_cookie_string(cookie_hash) }

        _, headers, = middleware.call(env)

        expect(from_cookie_string(headers["Set-Cookie"])["value"]).to eq(cookie_hash)
      end

      context "when cookie is malformed" do
        it "initializes the cookie with an empty hash" do
          env = { "HTTP_COOKIE" => "arpa_context=malformed_json" }

          _, headers, = middleware.call(env)

          expect(headers["Set-Cookie"]).to include("arpa_context=#{CGI.escape("{}")}")
        end
      end
    end

    context "when query is a write" do
      let(:query) { User.create!(name: SecureRandom.uuid, email: SecureRandom.uuid) }

      it "updates the cookie expiry date" do
        env = { "HTTP_COOKIE" => to_cookie_string({}) }

        _, headers, = middleware.call(env)

        cookie_expiry = from_cookie_string(headers["Set-Cookie"])["expires"]

        expect(Time.parse(cookie_expiry)).to eq((2 + 5).seconds.from_now) # proxy delay + cookie buffer
      end
    end

    context "when request comes from rails asset prefix" do
      before do
        rails       = double("Rails") # rubocop:disable RSpec/VerifiedDoubles
        application = double
        config      = double
        assets      = double

        allow(rails).to receive(:try).with(:application).and_return(application)
        allow(application).to receive(:try).with(:config).and_return(config)
        allow(config).to receive(:try).with(:assets).and_return(assets)
        allow(assets).to receive(:try).with(:prefix).and_return("/assets")

        stub_const("Rails", rails)
      end

      it "does not set current context" do
        env = {
          "PATH_INFO" => "/assets/application.js", "HTTP_COOKIE" => to_cookie_string({ "sqlite3_primary" => 0 })
        }

        middleware.call(env)

        expect(middleware.send(:current_context).to_h).to eq({})
      end
    end
  end
end
