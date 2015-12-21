module Straight
  module ExchangeRate

    class ForexAdapter < Adapter

      CROSS_RATE_CURRENCY = 'USD'
      DECIMAL_PRECISION = 2

      # Set half-even rounding mode
      # http://apidock.com/ruby/BigDecimal/mode/class
      BigDecimal.mode BigDecimal::ROUND_MODE, :banker

      def rate_for(currency_code)
        return 1 if currency_code == CROSS_RATE_CURRENCY
        super
        # call 'super' in descendant classes and return real rate
      end

    end

  end
end
