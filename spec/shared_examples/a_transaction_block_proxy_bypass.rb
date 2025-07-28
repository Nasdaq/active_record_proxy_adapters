# frozen_string_literal: true

RSpec.shared_examples_for "a transaction block proxy bypass" do
  subject(:run_test) { Model.exists? }

  let(:model_class_stub) do
    Class.new(model_class) do
      self.table_name = "users"
    end
  end

  let(:transaction_method_name) do
    :internal_execute
  end

  before do
    stub_const("Model", model_class_stub)

    allow(primary_adapter).to receive(:execute).and_call_original
    allow(primary_adapter).to receive(transaction_method_name).and_call_original
  end

  context "when an ActiveRecord transaction block is used" do
    it "doesn't use the proxied method to open a transaction" do
      model_class.transaction { run_test }

      expect(primary_adapter).not_to have_received(:execute).with("BEGIN", "TRANSACTION", any_args)
    end

    it "doesn't use the proxied method to close a transaction" do
      model_class.transaction { run_test }

      expect(primary_adapter).not_to have_received(:execute).with("COMMIT", "TRANSACTION", any_args)
    end

    it "uses the unproxied method to open a transaction" do
      model_class.transaction { run_test }

      expect(primary_adapter).to have_received(transaction_method_name).with("BEGIN", "TRANSACTION", any_args)
    end

    it "uses the unproxied method to close a transaction" do
      model_class.transaction { run_test }

      expect(primary_adapter).to have_received(transaction_method_name).with("COMMIT", "TRANSACTION", any_args)
    end

    context "when transaction is rolled back" do
      subject(:run_test) do
        Model.exists?
        raise ActiveRecord::Rollback
      end

      it "uses the unproxied method to rollback a transaction" do
        model_class.transaction { run_test }

        expect(primary_adapter).to have_received(transaction_method_name).with("ROLLBACK", "TRANSACTION", any_args)
      end
    end
  end
end
