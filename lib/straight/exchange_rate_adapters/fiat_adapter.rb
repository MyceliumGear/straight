module Straight
  module ExchangeRate

    class FiatAdapter < Adapter

      CROSS_RATE_CURRENCY = 'USD'
      SUPPORTED_CURRENCIES = %w(
        AUD BGN BRL CAD CHF CNY CZK DKK GBP HKD HRK HUF IDR ILS INR JPY
        KRW MXN MYR NOK NZD PHP PLN RON RUB SEK SGD THB TRY USD ZAR EUR
      )
      DECIMAL_PRECISION = 2

      # Set half-even rounding mode
      # http://apidock.com/ruby/BigDecimal/mode/class
      BigDecimal.mode BigDecimal::ROUND_MODE, :banker

      def rate_for(currency_code)
        return 1 if currency_code == CROSS_RATE_CURRENCY
        raise CurrencyNotSupported unless SUPPORTED_CURRENCIES.include?(currency_code)
        super
        # call 'super' in descendant classes and return real rate
      end

      def convert_from_currency(amount_in_currency, currency: CROSS_RATE_CURRENCY)
        return amount_in_currency if currency == CROSS_RATE_CURRENCY
        amount_in_currency.to_f / rate_for(currency)
      end

    end

  end
end
