# frozen_string_literal: true

RSpec.shared_context "a proxied method setup" do # rubocop:disable RSpec/ContextWording
  subject(:run_test) { proxy.public_send(method_name, sql) }

  let(:method_name) { nil }
  let(:proxy) { described_class.new(primary_adapter) }
  let(:read_only_error_class) { ActiveRecord::ReadOnlyError }
end
