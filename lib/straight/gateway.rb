module Straight

  # This module should be included into your own class to extend it with Gateway functionality.
  # For example, if you have a ActiveRecord model called Gateway, you can include GatewayModule into it
  # and you'll now be able to do everything Straight::Gateway can do, but you'll also get AR Database storage
  # funcionality, its validations etc.
  #
  # The right way to implement this would be to do it the other way: inherit from Straight::Gateway, then
  # include ActiveRecord, but at this point ActiveRecord doesn't work this way. Furthermore, some other libraries, like Sequel,
  # also require you to inherit from them. Thus, the module.
  #
  # When this module is included, it doesn't actually *include* all the methods, some are prepended (see Ruby docs on #prepend).
  # It is important specifically for getters and setters and as a general rule only getters and setters are prepended.
  #
  # If you don't want to bother yourself with modules, please use Straight::Gateway class and simply create new instances of it.
  # However, if you are contributing to the library, all new funcionality should go to either Straight::GatewayModule::Includable or
  # Straight::GatewayModule::Prependable (most likely the former).
  module GatewayModule

    # Raised when adapter's list (either Exchange or Blockchain adapters) is empty
    class NoAdaptersAvailable < StraightError;end
    class OrderAmountInvalid  < StraightError;end

    # Only add getters and setters for those properties in the extended class
    # that don't already have them. This is very useful with ActiveRecord for example
    # where we don't want to override AR getters and setters that set attributes.
    def self.included(base)
      base.class_eval do
        [
          :pubkey,
          :test_pubkey,
          :confirmations_required,
          :status_check_schedule,
          :blockchain_adapters,
          :test_blockchain_adapters,
          :exchange_rate_adapters, # TODO: rename to 'bitcoin_exchange_rate_adapters'
          :forex_rate_adapters,
          :order_callbacks,
          :order_class,
          :default_currency,
          :name,
          :address_provider,
          :address_provider_type,
          :address_derivation_scheme,
          :test_mode
        ].each do |field|
          attr_reader field unless base.method_defined?(field)
          attr_writer field unless base.method_defined?("#{field}=")
          prepend Prependable
          include Includable
        end
      end
    end

    # Determines the algorithm for consequitive checks of the order status.
    DEFAULT_STATUS_CHECK_SCHEDULE = -> (period, iteration_index) do
      iteration_index += 1
      if iteration_index >= 20
        period          *= 2
        iteration_index  = 0
      end
      return { period: period, iteration_index: iteration_index }
    end

    # If you are defining methods in this module, it means you most likely want to
    # call super() somehwere inside those methods.
    #
    # In short, the idea is to let the class we're being prepended to do its magic
    # after our methods are finished.
    module Prependable
    end

    module Includable

      def blockchain_adapters
        return test_blockchain_adapters if test_mode
        @blockchain_adapters
      end

      # Creates a new order for the address derived from the pubkey and the keychain_id argument provided.
      # See explanation of this keychain_id argument is in the description for the AddressProvider::Base#new_address method.
      def new_order(args)

        # Args: amount:, keychain_id: nil, currency: nil, btc_denomination: :satoshi
        #
        # The reason these arguments are supplied as a hash and not as named arguments
        # is because we don't know in advance which arguments are required for a particular
        # AddressAdapter. So we accept all, check manually for required ones like :amount,
        # set default values where needed and then hand them all to address_adapter.
        if args[:amount].nil? || !args[:amount].kind_of?(Numeric) || args[:amount] <= 0
          raise OrderAmountInvalid, "amount cannot be nil and should be more than 0"
        end
        # Setting default values

        if address_provider.takes_fees? &&
            !address_provider.currency_supported?(args[:currency])
          supported_currency = select_supported_currency_by_address_provider
          args[:amount] = convert_amount_to_supported_currency(args[:amount],
            args[:currency], supported_currency)
          args[:currency] = supported_currency
        end

        args[:currency]         ||= default_currency
        args[:btc_denomination] ||= :satoshi

        amount = args[:amount_from_exchange_rate] = amount_from_exchange_rate(
          args[:amount],
          currency:         args[:currency],
          btc_denomination: args[:btc_denomination]
        )

        if address_provider.takes_fees?
          address, amount = address_provider.new_address_and_amount(**args)
        else
          address = address_provider.new_address(**args)
        end

        order             = Kernel.const_get(order_class).new
        order.gateway     = self
        order.keychain_id = args[:keychain_id]
        order.address     = address
        order.amount      = amount
        order.block_height_created_at = fetch_latest_block_height rescue nil

        unless args[:currency] == "BTC"
          order.exchange_rate = current_exchange_rate(args[:currency])
          order.currency = args[:currency]
        end

        order
      end

      def fetch_transaction(tid, address: nil)
        Straight::BlockchainAdaptersDispatcher.new(blockchain_adapters) { |b| b.fetch_transaction(tid, address: address) }.result
      end

      def fetch_transactions_for(address)
        Straight::BlockchainAdaptersDispatcher.new(blockchain_adapters) { |b| b.fetch_transactions_for(address) }.result
      end

      def fetch_balance_for(address)
        Straight::BlockchainAdaptersDispatcher.new(blockchain_adapters) { |b| b.fetch_balance_for(address) }.result
      end

      def fetch_latest_block_height
        Straight::BlockchainAdaptersDispatcher.new(blockchain_adapters, &:latest_block_height).result
      end

      def keychain
        key = self.test_mode ? self.test_pubkey : self.pubkey
        @keychain ||= BTC::Keychain.new(xpub: key)
      end

      # This is a callback method called from each order
      # whenever an order status changes.
      def order_status_changed(order)
        @order_callbacks.each do |c|
          c.call(order)
        end
      end

      # Gets exchange rates from one of the exchange rate adapters,
      # then calculates how much BTC does the amount in the given currency represents.
      #
      # You can also feed this method various bitcoin denominations.
      # It will always return amount in Satoshis.
      def amount_from_exchange_rate(amount, currency:, btc_denomination: :satoshi)
        currency         = self.default_currency if currency.nil?
        btc_denomination = :satoshi              if btc_denomination.nil?
        currency = currency.to_s.upcase
        if currency == 'BTC'
          return Satoshi.new(amount, from_unit: btc_denomination).to_i
        end

        begin
          try_adapters(
            @exchange_rate_adapters,
            type: "exchange rate",
            priority_exception: Straight::ExchangeRate::Adapter::CurrencyNotSupported
          ) do |a|
            a.convert_from_currency(amount, currency: currency)
          end
        # At least one Bitcoin exchange adapter works, but none returned exchange rate for given currency
        rescue Straight::ExchangeRate::Adapter::CurrencyNotSupported
          amount_in_cross_currency = try_adapters(@forex_rate_adapters, type: "forex rate") do |a|
            a.convert_from_currency(amount, currency: currency)
          end
          try_adapters(@exchange_rate_adapters, type: "exchange rate") do |a|
            a.convert_from_currency(amount_in_cross_currency, currency: Straight::ExchangeRate::FiatAdapter::CROSS_RATE_CURRENCY)
          end
        end
      end

      def current_exchange_rate(currency=self.default_currency)
        currency = currency.to_s.upcase
        try_adapters(@exchange_rate_adapters, type: "exchange rate") do |a|
          a.rate_for(currency)
        end
      end

      def test_pubkey_missing?
        address_provider_type == :Bip32 && test_mode && test_pubkey.to_s.empty?
      end

      def pubkey_missing?
        address_provider_type == :Bip32 && !test_mode && pubkey.to_s.empty?
      end

      def address_provider_type
        @address_provider ? @address_provider.class.name.split('::')[-1].to_sym  : :Bip32
      end

      private

        def select_supported_currency_by_address_provider
          address_provider.class::SUPPORTED_CURRENCIES.first
        end

        def convert_amount_to_supported_currency(amount, currency, supported_currency)
          adapter = ExchangeRate::FixerAdapter.instance
          rate_for_supported_currency = adapter.rate_for(supported_currency)
          rate_for_currency = adapter.rate_for(currency)

          (amount * rate_for_supported_currency) / rate_for_currency
        end

        # Calls the block with each adapter until one of them does not fail.
        # Fails with the:
        #   - priority_exception, if it is set and was raised at least once
        #   - last exception otherwise
        def try_adapters(adapters, type: nil, raise_exceptions: [], priority_exception: nil, &block)

          # TODO: specify which adapters are unavailable (blockchain or exchange rate)
          raise NoAdaptersAvailable, "the list of #{type} adapters is empty or nil" if adapters.nil? || adapters.empty?

          last_exception = nil
          last_priority_exception = nil

          adapters.each_with_index do |adapter, index|
            begin
              result = yield(adapter)
              return result
            rescue => e
              raise e if raise_exceptions.include?(e)
              last_exception = e
              last_priority_exception = e if priority_exception && e.is_a?(priority_exception)
              # let's not log error for the last adapter, it will be re-raised anyway
              unless index == adapters.size - 1
                loglevel =
                  case e
                  when Straight::ExchangeRate::Adapter::CurrencyNotSupported
                    :debug
                  else
                    :error
                  end
                Straight.logger.send loglevel, "Adapter #{adapter.inspect} failed with #{e.inspect}:\n#{e.backtrace.join("\n")}"
              end
              # If an exception wasn't re-raised, it passes on to the next adapter and attempts to call a method on it
            end
          end
          raise last_priority_exception if last_priority_exception
          raise last_exception if last_exception
        end

    end

  end


  class Gateway

    include GatewayModule

    class << self
      def available_blockchain_adapters
        [
          Blockchain::BlockchainInfoAdapter.mainnet_adapter,
          Blockchain::MyceliumAdapter.mainnet_adapter
        ]
      end

      def available_exchange_rate_adapters
        [
          ExchangeRate::BitpayAdapter.instance,
          ExchangeRate::CoinbaseAdapter.instance,
          ExchangeRate::BitstampAdapter.instance,
          ExchangeRate::BtceAdapter.instance,
          ExchangeRate::KrakenAdapter.instance,
          ExchangeRate::LocalbitcoinsAdapter.instance,
          ExchangeRate::OkcoinAdapter.instance
        ]
      end

      def available_forex_rate_adapters
        [
          ExchangeRate::FixerAdapter.instance,
          ExchangeRate::YahooAdapter.instance
        ]
      end
    end

    def initialize
      @default_currency = 'BTC'
      @blockchain_adapters = self.class.available_blockchain_adapters
      @exchange_rate_adapters = self.class.available_exchange_rate_adapters
      @forex_rate_adapters = self.class.available_forex_rate_adapters
      @status_check_schedule = DEFAULT_STATUS_CHECK_SCHEDULE
      @address_provider = AddressProvider::Bip32.new(self)
      @test_mode = false
    end

    def order_class
      "Straight::Order"
    end

  end

end
