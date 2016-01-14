module Straight
  module ExchangeRate

    class BtcAdapter < Adapter

      def convert_from_currency(amount_in_currency, btc_denomination: :satoshi, currency: 'USD')
        btc_amount = amount_in_currency.to_f/rate_for(currency)
        Satoshi.new(btc_amount, from_unit: :btc, to_unit: btc_denomination).to_unit
      end

      def convert_to_currency(amount, btc_denomination: :satoshi, currency: 'USD')
        amount_in_btc = Satoshi.new(amount.to_f, from_unit: btc_denomination).to_btc
        amount_in_btc*rate_for(currency)
      end

    end

  end
end
