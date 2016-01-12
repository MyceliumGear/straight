require 'logger'
require 'btcruby'
require 'satoshi-unit'
require 'json'
require 'uri'
require 'open-uri'
require 'yaml'
require 'singleton'
require 'httparty'
require 'faraday'
require 'concurrent'
require_relative 'straight/faraday_monkeypatch'
require_relative 'straight/errors'

module Straight
  class << self
    attr_writer :logger
    def logger
      @logger ||= Logger.new('/dev/null')
    end
  end
end

require_relative 'core_ext/deep_get'

require_relative 'straight/blockchain_adapter'
require_relative 'straight/blockchain_adapters_dispatcher'
require_relative 'straight/blockchain_adapters/blockchain_info_adapter'
require_relative 'straight/blockchain_adapters/biteasy_adapter'
require_relative 'straight/blockchain_adapters/mycelium_adapter'
require_relative 'straight/blockchain_adapters/insight_adapter'
require_relative 'straight/blockchain_adapters/chain_com_adapter'

require_relative 'straight/exchange_rate_adapter'

require_relative 'straight/exchange_rate_adapters/btc_adapter'
require_relative 'straight/exchange_rate_adapters/btc_adapters/bitpay_adapter'
require_relative 'straight/exchange_rate_adapters/btc_adapters/coinbase_adapter'
require_relative 'straight/exchange_rate_adapters/btc_adapters/bitstamp_adapter'
require_relative 'straight/exchange_rate_adapters/btc_adapters/localbitcoins_adapter'
require_relative 'straight/exchange_rate_adapters/btc_adapters/okcoin_adapter'
require_relative 'straight/exchange_rate_adapters/btc_adapters/btce_adapter'
require_relative 'straight/exchange_rate_adapters/btc_adapters/kraken_adapter'
require_relative 'straight/exchange_rate_adapters/btc_adapters/average_rate_adapter'

require_relative 'straight/exchange_rate_adapters/fiat_adapter'
require_relative 'straight/exchange_rate_adapters/fiat_adapters/fixer_adapter'
require_relative 'straight/exchange_rate_adapters/fiat_adapters/yahoo_adapter'

require_relative 'straight/address_providers/bip32'

require_relative 'straight/transaction'
require_relative 'straight/order'
require_relative 'straight/gateway'
