require 'spec_helper'

RSpec.describe Straight::Blockchain::InsightAdapter do

  subject(:mainnet_adapter) { Straight::Blockchain::InsightAdapter.mainnet_adapter(url: "https://insight.mycelium.com/api") }

  before :all do
    VCR.configure do |c|
      c.default_cassette_options = {:record => :new_episodes}
    end
    VCR.insert_cassette 'blockchain_insight_adapter'
  end

  after :all do
    VCR.eject_cassette
  end

  let(:tx) { {
    tid: '6d638507f60a8cd6789087cd478524a65e8c85f079bb0772f782e6f6b27e2c74',
    amount: 16419497,
    block_height: 374619,
  } }

  it "fetches a single transaction" do
    transaction = mainnet_adapter.fetch_transaction(tx[:tid])
    expect(transaction[:total_amount]).to eq tx[:amount]
    expect(transaction[:confirmations]).to be > 0
    expect(transaction[:tid]).to eq tx[:tid]
    expect(transaction[:block_height]).to eq tx[:block_height]
  end

  it "gets the latest block number" do
    expect(mainnet_adapter.latest_block_height).to be >= 374620
  end

  it "fetches first transaction for the given address" do
    address = "14fUugavBtRG73BE9FCfoCYs3BBxtDxUL1"
    transactions = mainnet_adapter.fetch_transactions_for(address)
    expect(transactions).to be_kind_of(Array)
    expect(transactions).not_to be_empty
  end

  it "fetches balance for given address" do
    address = "14fUugavBtRG73BE9FCfoCYs3BBxtDxUL1"
    expect(mainnet_adapter.fetch_balance_for(address)).to be_kind_of Integer
  end

  it "raises exception if something wrong with network" do
    expect( -> { mainnet_adapter.send(:api_request, "/a-404-request", "tid") }).to raise_error(Straight::Blockchain::Adapter::RequestError)
  end

  it "raises exception if worng main_url" do
    adapter = Straight::Blockchain::InsightAdapter.mainnet_adapter(url: "https://insight.mycelium.com/wrong_api")
    expect{ adapter.fetch_transaction(tx[:tid])[:total_amount] }.to raise_error(Straight::Blockchain::Adapter::RequestError)
  end

  it "should return message if given wrong address" do
    expect{ mainnet_adapter.fetch_transactions_for("wrong_address") }.to raise_error(Straight::Blockchain::Adapter::BitcoinAddressInvalid)
  end
  
end
