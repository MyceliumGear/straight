require 'spec_helper'

RSpec.describe Straight::ExchangeRate::FixerAdapter do

  before :all do
    VCR.insert_cassette 'exchange_rate_adapters/fiat_adapters/fixer_adapter'
  end

  after :all do
    VCR.eject_cassette
  end

  before(:each) do
    @exchange_adapter = Straight::ExchangeRate::FixerAdapter.instance
  end

  it "finds the rate for currency code" do
    expect(@exchange_adapter.rate_for('RUB')).to be_kind_of(Numeric)
    expect( -> { @exchange_adapter.rate_for('KZT') }).to raise_error(Straight::ExchangeRate::Adapter::CurrencyNotSupported)
  end

  it "returns 1.0 when the currency is the FiatAdapter::CROSS_RATE_CURRENCY" do
    expect(@exchange_adapter.
      rate_for(Straight::ExchangeRate::FiatAdapter::CROSS_RATE_CURRENCY)).to eq(1.0)
  end
end
