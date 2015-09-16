require 'spec_helper'

RSpec.describe Straight::Blockchain::ChainComAdapter do

  before :all do
    VCR.insert_cassette 'blockchain_chain_com_adapter'
  end

  after :all do
    VCR.eject_cassette
  end

  describe "mainnet" do

    subject(:adapter) do
      Straight::Blockchain::ChainComAdapter.mainnet_adapter(api_key_id: 'e9868197f9a319dae135e01fba07cfcc')
    end

    let(:tid) { 'ae0d040f48d75fdc46d9035236a1782164857d6f0cca1f864640281115898560' }
    let(:address) { '3B1QZ8FpAaHBgkSB5gFt76ag5AW9VeP8xp' }

    it "fetches the balance for a given address" do
      expect(adapter.fetch_balance_for(address)).to be_kind_of(Integer)
    end

    it "fetches a single transaction" do
      transaction = adapter.fetch_transaction(tid)
      expect(transaction[:total_amount]).to eq(832947)
      expect(transaction[:block_height]).to eq 317124
    end

    it "fetches all transactions for the current address" do
      expect(adapter).to receive(:straighten_transaction).with(anything, address: address).at_least(:once)
      expect(adapter.fetch_transactions_for(address)).not_to be_empty
    end

    it "calculates the number of confirmations for each transaction" do
      expect(adapter.fetch_transaction(tid)[:confirmations]).to be > 0
    end

    it "gets a transaction id among other data" do
      expect(adapter.fetch_transaction(tid)[:tid]).to eq(tid)
    end

    it "calculates total_amount of a transaction for the given address only" do
      t = { 'outputs' => [{ 'value' => 1, 'addresses' => ['address1']}, { 'value' => 2, 'addresses' => ['address2']}] }
      expect(adapter.send(:straighten_transaction, t, address: 'address1')[:total_amount]).to eq(1)
    end

    it "raises an exception when something goes wrong with fetching data" do
      expect( -> { adapter.send(:api_request, "/a-404-request") }).to (
        raise_error(Straight::Blockchain::Adapter::RequestError)
      )
    end

    it 'raises an exception when sent wrong API key id' do
      expect( -> { Straight::Blockchain::ChainComAdapter.mainnet_adapter(api_key_id: nil) }).to (
        raise_error(Straight::Blockchain::ChainComAdapterApiKeyIdError)
      )
    end

  end

  describe "testnet" do

    subject(:adapter) do
      Straight::Blockchain::ChainComAdapter.testnet_adapter(api_key_id: 'e9868197f9a319dae135e01fba07cfcc')
    end

    let(:tid) { 'f24c7910cca6ca294cc295f3f30a47c2014385d816566e224ece9779e805a787' }
    let(:address) { '2NGNncDGmqKXwskzL6wKozqN2De32CRgocm' }

    it "fetches the balance for a given address" do
      expect(adapter.fetch_balance_for(address)).to be_kind_of(Integer)
    end

    it "fetches a single transaction" do
      expect(adapter.fetch_transaction(tid)[:total_amount]).to eq(16873967)
    end

    it "fetches all transactions for the current address" do
      expect(adapter).to receive(:straighten_transaction).with(anything, address: address).at_least(:once)
      expect(adapter.fetch_transactions_for(address)).not_to be_empty
    end

    it "calculates the number of confirmations for each transaction" do
      expect(adapter.fetch_transaction(tid)[:confirmations]).to be > 0
    end

    it "gets a transaction id among other data" do
      expect(adapter.fetch_transaction(tid)[:tid]).to eq(tid)
    end

    it "calculates total_amount of a transaction for the given address only" do
      t = { 'outputs' => [{ 'value' => 1, 'addresses' => ['address1']}, { 'value' => 2, 'addresses' => ['address2']}] }
      expect(adapter.send(:straighten_transaction, t, address: 'address1')[:total_amount]).to eq(1)
    end

    it "raises an exception when something goes wrong with fetching data" do
      expect( -> { adapter.send(:api_request, "/a-404-request") }).to (
        raise_error(Straight::Blockchain::Adapter::RequestError)
      )
    end

    it 'raises an exception when sent wrong API key id' do
      expect( -> { Straight::Blockchain::ChainComAdapter.testnet_adapter(api_key_id: nil) }).to (
        raise_error(Straight::Blockchain::ChainComAdapterApiKeyIdError)
      )
    end

  end

end
