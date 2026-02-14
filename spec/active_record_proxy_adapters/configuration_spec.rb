# frozen_string_literal: true

RSpec.describe ActiveRecordProxyAdapters::Configuration do
  describe "#stickiness_cookie_enabled" do
    subject(:stickiness_cookie_enabled) { configuration.stickiness_cookie_enabled }

    let(:configuration) { described_class.new }

    it "defaults to true" do
      expect(stickiness_cookie_enabled).to be(true)
    end

    context "when overridden" do
      it "equals the overridden value" do
        configuration.stickiness_cookie_enabled = false

        expect(stickiness_cookie_enabled).to be(false)
      end
    end
  end
end
