require 'spec_helper'

RSpec.describe Straight::Blockchain::BiteasyAdapter do

  subject(:adapter) { Straight::Blockchain::BiteasyAdapter.mainnet_adapter }

  before :all do
    VCR.insert_cassette 'blockchain_biteasy_adapter'
  end

  after :all do
    VCR.eject_cassette
  end

  it "fetches the balance for a given address" do
    address = "3B1QZ8FpAaHBgkSB5gFt76ag5AW9VeP8xp"
    expect(adapter.fetch_balance_for(address)).to be_kind_of(Integer)
  end

  it "fetches a single transaction" do
    tid = 'ae0d040f48d75fdc46d9035236a1782164857d6f0cca1f864640281115898560'
    transaction = adapter.fetch_transaction(tid)
    expect(transaction[:total_amount]).to eq 832947
    expect(transaction[:block_height]).to eq 317124
  end

  it "calculates total_amount of a transaction for the given address only" do
    t = { 'data' => {'outputs' => [{ 'value' => 1, 'to_address' => 'address1'}, { 'value' => 2, 'to_address' => 'address2'}] } }
    expect(adapter.send(:straighten_transaction, t, address: 'address1')[:total_amount]).to eq(1)
  end

  it "fetches all transactions for the current address" do
    address = "3B1QZ8FpAaHBgkSB5gFt76ag5AW9VeP8xp"
    expect(adapter).to receive(:straighten_transaction).with(anything, address: address).at_least(:once)
    expect(adapter.fetch_transactions_for(address)).not_to be_empty
  end

  it "calculates the number of confirmations for each transaction" do
    tid = 'ae0d040f48d75fdc46d9035236a1782164857d6f0cca1f864640281115898560'
    expect(adapter.fetch_transaction(tid)[:confirmations]).to be > 0
  end

  it "gets a transaction id among other data" do
    tid = 'ae0d040f48d75fdc46d9035236a1782164857d6f0cca1f864640281115898560'
    expect(adapter.fetch_transaction(tid)[:tid]).to eq(tid)
  end

  it "raises an exception when something goes wrong with fetching data" do
    expect( -> { adapter.send(:api_request, "/a-404-request") }).to raise_error(Straight::Blockchain::Adapter::RequestError)
  end

  it "uses the same Singleton instance" do
    a = Straight::Blockchain::BiteasyAdapter.mainnet_adapter
    b = Straight::Blockchain::BiteasyAdapter.mainnet_adapter
    expect(a).to eq(b)
  end

end
