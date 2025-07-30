# frozen_string_literal: true

RSpec.describe ActiveRecordProxyAdapters::DatabaseConfiguration do
  describe ".PROXY_DELAY" do
    subject { described_class::PROXY_DELAY }

    it { is_expected.to eq(2.seconds) }
  end

  describe ".CHECKOUT_TIMEOUT" do
    subject { described_class::CHECKOUT_TIMEOUT }

    it { is_expected.to eq(2.seconds) }
  end

  describe "#proxy_delay" do
    subject(:proxy_delay) { configuration.proxy_delay }

    let(:configuration) { described_class.new }

    it "defaults to PROXY_DELAY" do
      expect(proxy_delay).to eq(described_class::PROXY_DELAY)
    end

    context "when overriden" do
      it "equals the overriden value" do
        configuration.proxy_delay = 5.seconds

        expect(proxy_delay).to eq(5.seconds)
      end
    end
  end

  describe "#checkout_timeout" do
    subject(:checkout_timeout) { configuration.checkout_timeout }

    let(:configuration) { described_class.new }

    it "defaults to CHECKOUT_TIMEOUT" do
      expect(checkout_timeout).to eq(described_class::CHECKOUT_TIMEOUT)
    end

    context "when overridden" do
      it "equals the overridden value" do
        configuration.checkout_timeout = 5.seconds

        expect(checkout_timeout).to eq(5.seconds)
      end
    end
  end
end
