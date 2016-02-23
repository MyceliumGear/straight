require 'spec_helper'

RSpec.describe Straight::Gateway do

  before(:each) do
    @mock_adapter                  = double("mock blockchain adapter")
    allow(@mock_adapter).to receive(:testnet_adapter)
    allow(@mock_adapter).to receive(:latest_block_height).and_return(nil)
    @gateway                       = Straight::Gateway.new
    @gateway.pubkey                = "pubkey"
    @gateway.order_class           = "Straight::Order"
    @gateway.blockchain_adapters   = [@mock_adapter]
    @gateway.status_check_schedule = Straight::Gateway::DEFAULT_STATUS_CHECK_SCHEDULE
    @gateway.order_callbacks       = []
  end

  it "shares bitcoin exchange rate adapter(s) instances between all/multiple gateway instances" do
    gateway_2 = Straight::Gateway.new.tap do |g|
      g.pubkey                = "pubkey"
      g.order_class           = "Straight::Order"
      g.blockchain_adapters   = [@mock_adapter]
      g.status_check_schedule = Straight::Gateway::DEFAULT_STATUS_CHECK_SCHEDULE
      g.order_callbacks       = []
    end
    # Checking if exchange rate adapters are the same objects for both gateways
    @gateway.instance_variable_get(:@exchange_rate_adapters).each_with_index do |adapter, i|
      expect(gateway_2.instance_variable_get(:@exchange_rate_adapters)[i]).to be adapter
    end
  end

  it "shares forex rate adapter(s) instances between all/multiple gateway instances" do
    gateway_2 = Straight::Gateway.new.tap do |g|
      g.pubkey                = "pubkey"
      g.order_class           = "Straight::Order"
      g.blockchain_adapters   = [@mock_adapter]
      g.status_check_schedule = Straight::Gateway::DEFAULT_STATUS_CHECK_SCHEDULE
      g.order_callbacks       = []
    end
    # Checking if exchange rate adapters are the same objects for both gateways
    @gateway.instance_variable_get(:@forex_rate_adapters).each_with_index do |adapter, i|
      expect(gateway_2.instance_variable_get(:@forex_rate_adapters)[i]).to be adapter
    end
  end

  it "passes methods on to the available adapter" do
    @gateway.instance_variable_set('@blockchain_adapters', [@mock_adapter])
    expect(@mock_adapter).to receive(:fetch_transaction).once.and_return(true)
    @gateway.fetch_transaction("xxx")
  end

  it "uses the next availabale adapter when something goes wrong with the current one" do
    another_mock_adapter = double("another_mock blockchain adapter")
    @gateway.instance_variable_set('@blockchain_adapters', [@mock_adapter, another_mock_adapter])
    allow(@mock_adapter).to receive(:fetch_transaction).once.and_raise(Straight::StraightError)
    expect(another_mock_adapter).to receive(:fetch_transaction).once.and_return(true)
    @gateway.fetch_transaction("xxx")
  end

  it "creates new orders and addresses for them" do
    @gateway.pubkey   = 'xpub661MyMwAqRbcFhUeRviyfia1NdfX4BAv5zCsZ6HqsprRjdBDK8vwh3kfcnTvqNbmi5S1yZ5qL9ugZTyVqtyTZxccKZzMVMCQMhARycvBZvx'
    expected_address  = '1NEvrcxS3REbJgup8rMA4QvMFFSdWTLvM'
    expect(@gateway.new_order(amount: 1, keychain_id: 1).address).to eq(expected_address)
  end

  it "calls all the order callbacks" do
    callback1                = double('callback1')
    callback2                = double('callback1')
    @gateway.pubkey          = BTC::Keychain.new(seed: 'test').xpub
    @gateway.order_callbacks = [callback1, callback2]

    order = @gateway.new_order(amount: 1, keychain_id: 1)
    expect(callback1).to receive(:call).with(order)
    expect(callback2).to receive(:call).with(order)
    @gateway.order_status_changed(order)
  end

  describe "when the address provider doesn't support the selected currency" do
    it "converts the currency to one the address provider supports" do
      @gateway.address_provider = AddressProvider.new(provider: :cashila)
      allow(@gateway.address_provider).to receive(:new_address_and_amount)
      allow(@gateway).to receive(:select_supported_currency_by_address_provider).
        and_return("EUR")
      expect(@gateway).to receive(:amount_from_exchange_rate).
        with(0.91996, currency: "EUR", btc_denomination: :satoshi)
      @gateway.new_order(amount: 1, keychain_id: 1, currency: "USD")
    end
  end

  describe "exchange rate calculation" do

    it "sets order amount in satoshis calculated from another currency" do
      adapter = Straight::ExchangeRate::BitpayAdapter.instance
      allow(adapter).to receive(:rate_for).and_return(450.5412)
      @gateway.exchange_rate_adapters = [adapter]
      expect(@gateway.amount_from_exchange_rate(2252.706, currency: 'USD')).to eq(500000000)
    end

    it "tries various exchange adapters until one of them actually returns an exchange rate" do
      adapter1 = Straight::ExchangeRate::BitpayAdapter.instance
      adapter2 = Straight::ExchangeRate::BitpayAdapter.instance
      allow(adapter1).to receive(:rate_for).and_return( -> { raise "connection problem" })
      allow(adapter2).to receive(:rate_for).and_return(450.5412)
      @gateway.exchange_rate_adapters = [adapter1, adapter2]
      expect(@gateway.amount_from_exchange_rate(2252.706, currency: 'USD')).to eq(500000000)
    end

    it "converts btc denomination into satoshi if provided with :btc_denomination" do
      expect(@gateway.amount_from_exchange_rate(5, currency: 'BTC', btc_denomination: :btc)).to eq(500000000)
    end

    it "accepts string as amount and converts it properly" do
      expect(@gateway.amount_from_exchange_rate('0.5', currency: 'BTC', btc_denomination: :btc)).to eq(50000000)
    end

    it "simply fetches current exchange rate for 1 BTC" do
      @adapter = @gateway.exchange_rate_adapters[-1]
      allow(@adapter).to receive(:get_rate_value_from_hash).and_return('21.5')
      expect(@gateway.current_exchange_rate('USD')).not_to be_nil
    end

    it "uses forex adapters to convert unknown (to bitcoin exchange adapters) currencies" do
      adapter1 = Straight::ExchangeRate::BitpayAdapter.instance
      adapter2 = Straight::ExchangeRate::BitstampAdapter.instance
      allow(adapter1).to receive(:rate_for).with('RUB').and_raise(Straight::ExchangeRate::Adapter::CurrencyNotSupported)
      allow(adapter1).to receive(:rate_for).with('USD').and_return(450.5412)
      allow(adapter2).to receive(:rate_for).and_raise("connection problem")
      @gateway.exchange_rate_adapters = [adapter1, adapter2]

      forex1 = Straight::ExchangeRate::FixerAdapter.instance
      expect(forex1).to receive(:rate_for).and_return(72.0)
      @gateway.forex_rate_adapters = [forex1]

      expect(@gateway.amount_from_exchange_rate(162194.832, currency: 'RUB')).to eq(500000000)
    end
  end

  describe "test mode" do

    let(:testnet_adapters) { [Straight::Blockchain::MyceliumAdapter.testnet_adapter] }

    it "is not activated on initialize" do
      expect(@gateway.test_mode).to be false
    end

    it "is using testnet" do
      @gateway.test_mode = true
      allow(@mock_adapter).to receive(:testnet_adapters).and_return(true)
      expect(@gateway.blockchain_adapters).to eq(@gateway.test_blockchain_adapters)
    end

    it "is disabled and return previous saved adapters" do
      expect(@gateway.blockchain_adapters).to eq([@mock_adapter])
    end

    it "generate get keychain in testnet" do

    end
    it "creates new orders and addresses for them" do
      @gateway.pubkey   = 'tpubDCzMzH5R7dvZAN7jNyZRUXxuo8XdRmMd7gmzvHs9LYG4w2EBvEjQ1Drm8ZXv4uwxrtUh3MqCZQJaq56oPMghsbtFnoLi9JBfG7vRLXLH21r'
      expected_address  = '1LUCZQ5habZZMRz6XeSqpAQUZEULggzzgE'
      expect(@gateway.new_order(amount: 1, keychain_id: 1).address).to eq(expected_address)
    end


  end

end

AddressProvider = Struct.new(:provider) do
  def takes_fees?
    true
  end

  def currency_supported?(currency)
    currency == "EUR"
  end
end
