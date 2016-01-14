require 'uri'

module Straight
  module ExchangeRate
    class YahooAdapter < FiatAdapter
      # Example URL (follow to un-shorten): http://goo.gl/62Aedt
      FETCH_URL = "http://query.yahooapis.com/v1/public/yql?" + URI.encode_www_form(
        format: 'json',
        env: "store://datatables.org/alltableswithkeys",
        q: "SELECT * FROM yahoo.finance.xchange WHERE pair IN" +
          # The following line is building array string in SQL: '("USDJPY", "USDRUB", ...)'
          "(#{SUPPORTED_CURRENCIES.map{|x| '"' + CROSS_RATE_CURRENCY.upcase + x.upcase + '"'}.join(',')})"
      )

      def rate_for(currency_code)
        super
        rates = @rates.deep_get('query', 'results', 'rate')
        rate = rates && rates.find{|x| x['id'] == CROSS_RATE_CURRENCY + currency_code.upcase}
        rate = rate && rate['Rate']
        rate_to_f(rate)
      end
    end
  end
end
