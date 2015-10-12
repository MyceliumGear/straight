require 'spec_helper'

RSpec.describe Straight::Blockchain do

  it "should return not namespaced adapter" do
    class MyAdapter; end
    expect(Straight::Blockchain.const_get("MyAdapter")).to eq(MyAdapter)
  end

  it "should return real constant" do
    expect(Straight::Blockchain.const_get("MyceliumAdapter")).to eq(Straight::Blockchain::MyceliumAdapter)
  end

end
