require 'spec_helper'

RSpec.describe Straight::BlockchainAdaptersDispatcher do

  before(:each) do
    @adapters = [Straight::Blockchain::InsightAdapter, Straight::Blockchain::MyceliumAdapter,
                 Straight::Blockchain::BiteasyAdapter]
  end

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
    expect(@adapters[0]).to receive(:fetch_transaction).once.and_return(nil)
    expect(@adapters[1]).to receive(:fetch_transaction).once.and_return(return_result)
    dispatcher = Straight::BlockchainAdaptersDispatcher.new(@adapters){ |b| b.fetch_transaction("123") }
    expect(dispatcher.result).to eq(return_result)
  end
  
end
