module Straight
  module Blockchain

    class InsightAdapter < Adapter

      def self.support_mainnet?
        true
      end

      def self.support_testnet?
        true
      end

      def self.mainnet_adapter(url:)
        new(url)
      end

      def self.testnet_adapter(url:)
        new(url)
      end

      def initialize(url)
        @base_url = url
      end

      def fetch_transaction(tid, address: nil)
        res = api_request("/tx/", tid)
        straighten_transaction(res, address: address)
      end

      def fetch_transactions_for(address)
        res = api_request("/addr/", address)
        (res['transactions'] || []).map { |tid| fetch_transaction(tid, address: address) }
      end

      def fetch_balance_for(address)
        res = api_request("/addr/", address)
        res["balanceSat"].to_i
      end

      def latest_block_height(**)
        api_request('/status', '')['info']['blocks']
      end

    private

      def api_request(place, val)
        req_url = @base_url + place + val
        conn = Faraday.new(url: req_url, ssl: { verify: false }) do |faraday|
          faraday.adapter Faraday.default_adapter
        end
        result = conn.get do |req|
          req.headers['Content-Type'] = 'application/json'
        end
        JSON.parse(result.body)
      rescue JSON::ParserError => e
        raise BitcoinAddressInvalid, message: "address in question: #{val}" if e.message.include?("Invalid address")
        raise RequestError, YAML::dump(e)
      rescue => e
        raise RequestError, YAML::dump(e)
      end

      def straighten_transaction(transaction, address: nil)
        total_amount = 0
        tid = transaction["txid"]
        vouts = transaction['vout'].select { |o| o && o['scriptPubKey'] && o['scriptPubKey']['addresses'] }
        vouts.each do |o|
          total_amount += Satoshi.new(o["value"]) if address.nil? || address == o["scriptPubKey"]["addresses"].first
        end
        confirmations = transaction["confirmations"]
        outs = vouts.map { |o| {amount: Satoshi.new(o["value"]).to_i, receiving_address: o["scriptPubKey"]["addresses"].first} }

        block_height = transaction['blockheight']
        if block_height.to_s.empty? && !transaction['blockhash'].to_s.empty?
          block = api_request('/block/', transaction['blockhash'])
          block_height = block['height']
        end

        {
          tid:           tid,
          total_amount:  total_amount,
          confirmations: confirmations || 0,
          block_height:  block_height,
          outs:          outs || [],
          meta: {
            fetched_via: self,
          },
        }
      end

    end

  end
end
