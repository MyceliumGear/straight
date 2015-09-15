require 'spec_helper'

RSpec.describe Straight::Blockchain::MyceliumAdapter do

  subject(:adapter) { Straight::Blockchain::MyceliumAdapter.mainnet_adapter }

  before :all do
    VCR.insert_cassette 'blockchain_mycelium_adapter'
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
    address = "1NX8bgWdPq2NahtTbTUAAdsTwpMpvt7nLy"
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

  it "gets the latest block number" do
    expect(adapter.latest_block_height).to be >= 374620
  end

  it "caches latestblock requests" do
    latest_block_response = double('Mycelium WAPI latest block response')
    expect(latest_block_response).to receive(:body).and_return('{ "r": { "height": 1 }}') 
    faraday_mock = double("Faraday Request Mock")
    expect(faraday_mock).to receive(:post).and_return(latest_block_response) 
    expect(Faraday).to receive(:new).once.and_return(faraday_mock)
    adapter.send(:calculate_confirmations, 1, force_latest_block_reload: true)
    adapter.send(:calculate_confirmations, 1)
    adapter.send(:calculate_confirmations, 1)
    adapter.send(:calculate_confirmations, 1)
    adapter.send(:calculate_confirmations, 1)
  end

  it "raises an exception when something goes wrong with fetching datd" do
    expect( -> { adapter.send(:api_request, "/a-404-request") }).to raise_error(Straight::Blockchain::Adapter::RequestError)
  end

  it "using next server if previous failed" do
    expect(Faraday).to receive(:new).at_least(2).times.and_raise(StandardError)
    begin 
      adapter.send(:calculate_confirmations, 1)
    rescue
      expect(adapter.instance_variable_get(:@base_url)).to eq(Straight::Blockchain::MyceliumAdapter::MAINNET_SERVERS[2])
    end
  end

  it "rescue from JSON parser error as StandardError" do
    expect(Faraday).to receive(:new).at_least(3).times.and_raise(JSON::ParserError)
    expect {
      adapter.send(:calculate_confirmations, 1)
    }.to raise_error(StandardError)
  end

  it "raise errors if all servers failed" do
    latest_block_response = double('Mycelium WAPI latest block response')
    expect(latest_block_response).to receive(:body).at_least(3).times.and_return('') 
    faraday_mock = double("Faraday Request Mock")
    expect(faraday_mock).to receive(:post).at_least(3).and_return(latest_block_response)
    expect(Faraday).to receive(:new).at_least(3).times.and_return(faraday_mock)
    expect {
      adapter.send(:calculate_confirmations, 1)
    }.to raise_error(Straight::Blockchain::Adapter::RequestError)
  end
  
  it "fetches data from testnet for specific address" do
    VCR.use_cassette "wapitestnet" do
      adapter = Straight::Blockchain::MyceliumAdapter.testnet_adapter
      address = "mjRmkmYzvZN3cA3aBKJgYJ65epn3WCG84H"
      expect(adapter).to receive(:straighten_transaction).with(anything, address: address).at_least(:once).and_return(1)
      expect(adapter.fetch_transactions_for(address)).to eq([1])
    end
  end

end
