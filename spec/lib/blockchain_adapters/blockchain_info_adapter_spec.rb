require 'spec_helper'

RSpec.describe Straight::Blockchain::BlockchainInfoAdapter do

  subject(:adapter) { Straight::Blockchain::BlockchainInfoAdapter.mainnet_adapter }

  before :all do
    VCR.insert_cassette 'blockchain_blockchain_info_adapter'
  end

  after :all do
    VCR.eject_cassette
  end

  it "fetches all transactions for the current address" do
    address = "3B1QZ8FpAaHBgkSB5gFt76ag5AW9VeP8xp"
    expect(adapter).to receive(:straighten_transaction).with(anything, address: address).at_least(:once)
    expect(adapter.fetch_transactions_for(address)).not_to be_empty
  end

  it "fetches the balance for a given address" do
    address = "3B1QZ8FpAaHBgkSB5gFt76ag5AW9VeP8xp"
    expect(adapter.fetch_balance_for(address)).to be_kind_of(Integer)
  end

  it "fetches a single transaction" do
    tid = 'ae0d040f48d75fdc46d9035236a1782164857d6f0cca1f864640281115898560'
    transaction = adapter.fetch_transaction(tid)
    expect(transaction[:total_amount]).to eq 832947
    expect(transaction[:confirmations]).to be > 0
    expect(transaction[:tid]).to eq tid
    expect(transaction[:block_height]).to eq 317124
  end

  it "gets latest block height" do
    expect(adapter.latest_block_height).to be >= 374620
  end

  it "caches blockchain.info latestblock requests" do
    expect(adapter).to receive(:api_request).once.and_return({ "height" => 1 })
    adapter.send(:calculate_confirmations, { "block_height" => 1 }, force_latest_block_reload: true)
    adapter.send(:calculate_confirmations, { "block_height" => 1 })
    adapter.send(:calculate_confirmations, { "block_height" => 1 })
    adapter.send(:calculate_confirmations, { "block_height" => 1 })
    adapter.send(:calculate_confirmations, { "block_height" => 1 })
  end

  it "raises an exception when something goes wrong with fetching datd" do
    expect( -> { adapter.send(:api_request, "/a-404-request") }).to raise_error(Straight::Blockchain::Adapter::RequestError)
  end

  it "calculates total_amount of a transaction for the given address only" do
    t = { 'out' => [{ 'value' => 1, 'addr' => 'address1'}, { 'value' => 1, 'addr' => 'address2'}] }
    expect(adapter.send(:straighten_transaction, t, address: 'address1')[:total_amount]).to eq(1)
  end
end
