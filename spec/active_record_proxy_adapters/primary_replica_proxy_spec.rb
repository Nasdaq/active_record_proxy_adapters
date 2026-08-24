# frozen_string_literal: true

RSpec.describe ActiveRecordProxyAdapters::PrimaryReplicaProxy do
  subject(:proxy) { described_class.new(primary_connection) }

  let(:primary_connection) do
    db_config = Struct.new(:name).new("primary")
    pool = Struct.new(:db_config).new(db_config)
    Struct.new(:pool).new(pool)
  end

  describe "SQL normalization" do
    it "removes leading block and line comments" do
      sql = " /* application:api */\r\n-- controller:index\r/* action:show */\nSELECT 1  "

      expect(normalize(sql)).to eq("SELECT 1")
    end

    it "preserves comments and comment-like text inside the statement" do
      sql = "/* query tag */ SELECT '/* literal */ -- literal' /* optimizer hint */"

      expect(normalize(sql)).to eq("SELECT '/* literal */ -- literal' /* optimizer hint */")
    end

    it "routes a commented SELECT to the replica" do
      expect(proxy.send(:need_primary?, normalize("/* query tag */ SELECT 1"))).to be(false)
    end

    it "sends a commented SET to all connections" do
      expect(proxy.send(:need_all?, normalize("/* query tag */ SET statement_timeout = 1000"))).to be(true)
    end

    it "keeps a commented SET LOCAL on one connection" do
      expect(proxy.send(:need_all?, normalize("/* query tag */ SET LOCAL statement_timeout = 1000"))).to be(false)
    end

    it "recognizes a commented INSERT as a write" do
      sql = normalize("/* query tag */ INSERT INTO users (name) VALUES ('Jane')")

      expect(proxy.send(:write_statement?, sql)).to be(true)
    end
  end

  def normalize(sql)
    proxy.send(:coerce_query_to_string, sql)
  end
end
