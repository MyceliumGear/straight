require 'spec_helper'

RSpec.describe Straight::Transaction do

  it "has from_hash constructor" do
    expect(Straight::Transaction.from_hash(tid: 1)).to eq Straight::Transaction.new(1)
    expect(Straight::Transaction.from_hash(amount: 1)).to eq Straight::Transaction.new(nil, 1)
    expect(Straight::Transaction.from_hash(confirmations: 1)).to eq Straight::Transaction.new(nil, nil, 1)
    expect(Straight::Transaction.from_hash(block_height: 1)).to eq Straight::Transaction.new(nil, nil, nil, 1)
    expect(Straight::Transaction.from_hash(tid: 1, amount: 2, confirmations: 3, block_height: 4)).to eq Straight::Transaction.new(1, 2, 3, 4)
  end

  it "has from_hashes constructor" do
    expect(Straight::Transaction.from_hashes [{tid: 1}, {tid: 2}]).to eq [Straight::Transaction.new(1), Straight::Transaction.new(2)]
  end

end
