require 'spec_helper'

RSpec.describe Straight::BlockchainAdaptersDispatcher do

  before(:each) do
    @adapters = [Straight::Blockchain::InsightAdapter, Straight::Blockchain::MyceliumAdapter,
                 Straight::Blockchain::BiteasyAdapter]
  end

  after(:each) { @adapters = nil }

  it "gets adapters according config number - STEP" do
    dispatcher = Straight::BlockchainAdaptersDispatcher.new(@adapters)
    expect(dispatcher.get_adapters.size).to eq(2)
  end

  it "increases #list_position on STEP" do
    dispatcher = Straight::BlockchainAdaptersDispatcher.new(@adapters)
    dispatcher.get_adapters
    expect(dispatcher.list_position).to eq(2)
  end

  it "sets #step according to size of adapters" do
    dispatcher = Straight::BlockchainAdaptersDispatcher.new(@adapters)
    2.times { dispatcher.get_adapters }
    expect(dispatcher.step).to eq(1)
  end

  it "returns value from second adapter" do
    return_result = "qwer"
    expect(@adapters[0]).to receive(:fetch_transaction).once.and_raise(StandardError)
    expect(@adapters[1]).to receive(:fetch_transaction).once.and_return(return_result)
    dispatcher = Straight::BlockchainAdaptersDispatcher.new(@adapters) { |b| b.fetch_transaction("123") }
    expect(dispatcher.result).to eq(return_result)
  end

  it "shold works with fault strategy"  do
    res = "third_adapter"
    allow(@adapters[0]).to receive(:fetch_transaction).and_raise(StandardError)
    allow(@adapters[1]).to receive(:fetch_transaction).and_raise(StandardError)
    allow(@adapters[2]).to receive(:fetch_transaction).and_return(res)
    dispatcher = Straight::BlockchainAdaptersDispatcher.new(@adapters) { |b| b.fetch_transaction("123") }
    expect(dispatcher.result).to eq(res)
  end

  it "raises timeout if all adapters not answered in specific amount of time" do
    allow(@adapters[0]).to receive(:fetch_transaction) { sleep(0.1) }
    Straight::BlockchainAdaptersDispatcher.const_set("TIMEOUT", 0.01)
    expect {
      Straight::BlockchainAdaptersDispatcher.new(@adapters) { |b| b.fetch_transaction("123") }
    }.to raise_error(TimeoutError)
  end
  
end
