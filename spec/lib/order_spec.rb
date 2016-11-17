require 'spec_helper'

RSpec.describe Straight::Order do

  class Straight::Order

    def status=(new_value)
      # we later make sure this method also gets called
      @original_status_setter_called = true
    end

  end

  before(:each) do
    @gateway = double("Straight Gateway mock")
    @order   = Straight::Order.new
    @order.amount      = 10
    @order.gateway     = @gateway
    @order.address     = 'address'
    @order.keychain_id = 1
    allow(@gateway).to receive(:order_status_changed).with(@order)
    allow(@gateway).to receive(:fetch_transactions_for).with(@order.address).and_return([{ tid: 'xxx', total_amount: 10}])
    allow(@gateway).to receive(:donation_mode).with(no_args).and_return(false)
  end

  it "follows status check schedule" do
    allow(@gateway).to receive(:fetch_transactions_for).with('address').and_return([])
    allow(@gateway).to receive(:status_check_schedule).and_return(Straight::Gateway::DEFAULT_STATUS_CHECK_SCHEDULE)
    [10, 20, 40, 80, 160, 320, 640].each do |i|
      expect(@order).to receive(:sleep).with(i).exactly(20).times
    end
    @order.start_periodic_status_check(duration: 25400)
  end

  it "gets the last transaction for the current address, caches the request" do
    expect(@gateway).to receive(:fetch_transactions_for).with(@order.address).once.and_return({})
    @order.transactions
    @order.transactions
  end

  it "gets all transactions for the current address, caches the request" do
    expect(@gateway).to receive(:fetch_transactions_for).with(@order.address).once.and_return([{tid: 't1'}, {tid: 't2'}])
    expect(@order.transaction.tid).to eq 't1'
    expect(@order.transaction.tid).to eq 't1'
  end

  it "displays order attributes as json" do
    allow(@order).to receive(:status).and_return(1)
    expect(@order.to_json).to eq('{"status":1,"amount":10,"address":"address","tid":null,"transaction_ids":[]}')
  end

  it "returns amount in btc as a string" do
    @order.amount = 1
    expect(@order.amount_in_btc).to eq(0.00000001)
    expect(@order.amount_in_btc(as: :string)).to eq('0.00000001')
  end

  it "returns amount_paid in btc as a string" do
    @order.amount_paid = 1
    expect(@order.amount_in_btc(field: @order.amount_paid)).to eq(0.00000001)
    expect(@order.amount_in_btc(field: @order.amount_paid, as: :string)).to eq("0.00000001")
  end

  describe "assigning statuses" do

    before(:each) do
      allow(@gateway).to receive(:confirmations_required).and_return(1)
    end

    it "doesn't reload the transaction unless forced" do
      @order.instance_variable_set(:@status, 2)
      expect(@order).to_not receive(:transaction)
      @order.status
    end

    it "sets status to :new upon order creation" do
      expect(@order.instance_variable_get(:@status)).to eq(0)
      expect(@order.instance_variable_get(:@old_status)).to eq(nil)
    end

    it "sets status to :new if no transaction issued" do
      expect(@order).to receive(:transaction).at_most(3).times.and_return(nil)
      expect(@order.status(reload: true)).to eq(0)
      expect(@order.status(as_sym: true)).to eq :new
    end

    it "sets status to :unconfirmed if transaction doesn't have enough confirmations" do
      transaction = Straight::Transaction.from_hash(confirmations: 0, total_amount: @order.amount)
      expect(@order).to receive(:transaction).at_most(3).times.and_return(transaction)
      expect(@order.status(reload: true)).to eq(1)
      allow(@gateway).to receive(:donation_mode).with(no_args).and_return(true)
      expect(@order.status(reload: true)).to eq(1)
    end

    it "sets status to :paid if transaction has enough confirmations and the amount is correct" do
      transaction = Straight::Transaction.from_hash(confirmations: 1, total_amount: @order.amount)
      expect(@order).to receive(:transaction).at_most(3).times.and_return(transaction)
      expect(@order.status(reload: true)).to eq(2)
      expect(@order.status(as_sym: true)).to eq :paid
    end

    it "sets status to :paid on any payment if gateway is in donation mode" do
      allow(@gateway).to receive(:donation_mode).with(no_args).and_return(true)
      transaction = Straight::Transaction.from_hash(confirmations: 1, total_amount: (@order.amount - (@order.amount / 2)))
      expect(@order).to receive(:transaction).at_most(3).times.and_return(transaction)
      expect(@order.status(reload: true)).to eq(2)
    end

    it "sets status to :partially_paid if the total amount in a transaction is less than the amount of order" do
      transaction = Straight::Transaction.from_hash(confirmations: 1, total_amount: @order.amount-1)
      expect(@order).to receive(:transaction).at_most(3).times.and_return(transaction)
      expect(@order.status(reload: true)).to eq(-3)
    end

    it "sets status to :overderpaid if the total amount in a transaction is more than the amount of order" do
      transaction = Straight::Transaction.from_hash(confirmations: 1, total_amount: @order.amount+1)
      expect(@order).to receive(:transaction).at_most(3).times.and_return(transaction)
      expect(@order.status(reload: true)).to eq(4)
    end

    it "invokes a callback on the gateway when status changes" do
      transaction = Straight::Transaction.from_hash(confirmations: 1, total_amount: @order.amount)
      allow(@order).to receive(:transaction).and_return(transaction)
      expect(@gateway).to receive(:order_status_changed).with(@order)
      @order.status(reload: true)
    end

    it "calls the original status setter of the class that the module is included into" do
      expect(@order.instance_variable_get(:@original_status_setter_called)).to be_falsy
      @order.status = 1
      expect(@order.instance_variable_get(:@original_status_setter_called)).to be_truthy
    end

    it "saves the old status in the old_status property" do
      @order.status = 2
      expect(@order.old_status).to eq(0)
    end

    it 'is have be nil in amount_paid if order not paid' do
      @order.status
      expect(@order.amount_paid).to eq(nil)
    end

    it 'is have amount_paid set to total_amount if order paid' do
      transaction = Straight::Transaction.from_hash(confirmations: 100, total_amount: 10)
      allow(@order).to receive(:transaction).and_return(transaction)

      @order.status(reload: true)
      expect(@order.amount_paid).to eq(10)
    end

    it "uses transactions_since if block_height_created_at is set" do
      allow(@gateway).to receive(:confirmations_required).and_return(0)
      allow(@order).to receive(:transactions).and_return(Straight::Transaction.from_hashes [{tid: '3', confirmations: 0, total_amount: @order.amount}, {tid: '2', confirmations: 1, total_amount: 3, block_height: 100000}, {tid: '1', confirmations: 100, total_amount: 1, block_height: 99999}])

      # only the latest transaction is accepted
      expect(@order.status(reload: true)).to eq 2
      expect(@order.amount_paid).to eq @order.amount
      expect(@order.accepted_transactions.size).to eq 1

      @order.instance_variable_set :@status, nil

      # unconfirmed transaction is accepted
      @order.block_height_created_at = 100000
      expect(@order.status(reload: true)).to eq 2
      expect(@order.amount_paid).to eq @order.amount
      expect(@order.accepted_transactions.size).to eq 1

      @order.instance_variable_set :@status, nil

      # two transactions are accepted
      @order.block_height_created_at = 99999
      expect(@order.status(reload: true)).to eq 4
      expect(@order.amount_paid).to eq @order.amount + 3
      expect(@order.accepted_transactions.size).to eq 2

      @order.instance_variable_set :@status, nil
      allow(@gateway).to receive(:confirmations_required).and_return(1)

      # when unconfirmed total_amount >= order.amount, order gets :unconfirmed status
      @order.block_height_created_at = 99999
      expect(@order.status(reload: true)).to eq 1
      expect(@order.amount_paid).to eq @order.amount + 3
      expect(@order.accepted_transactions.size).to eq 2

      @order.instance_variable_set :@status, nil
      allow(@order).to receive(:transactions).and_return(Straight::Transaction.from_hashes [{confirmations: 0, total_amount: @order.amount - 1}])

      # when total_amount < order.amount, order gets :partially_paid status
      expect(@order.status(reload: true)).to eq -3
      expect(@order.amount_paid).to eq @order.amount - 1
      expect(@order.accepted_transactions.size).to eq 1
    end

  end

  describe "assigning statuses with zero confirmations_required" do

    before(:each) do
      allow(@gateway).to receive(:confirmations_required).and_return(0)
    end

    it "sets status to :paid on any payment if gateway is in donation mode" do
      allow(@gateway).to receive(:donation_mode).with(no_args).and_return(true)
      transaction = Straight::Transaction.from_hash(confirmations: 0, total_amount: (@order.amount - (@order.amount / 2)))
      expect(@order).to receive(:transaction).at_most(3).times.and_return(transaction)
      expect(@order.status(reload: true)).to eq(2)
    end
  end
end
