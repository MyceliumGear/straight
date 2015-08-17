module Straight
  module Blockchain

    class ChainComAdapter < Adapter

      def self.mainnet_adapter(api_key_id:)
        instance = self.instance
        instance._initialize('https://api.chain.com/v2/bitcoin', api_key_id)
        instance
      end

      def self.testnet_adapter(api_key_id:)
        instance = self.instance
        instance._initialize('https://api.chain.com/v2/testnet3', api_key_id)
        instance
      end

      def _initialize(base_url, api_key_id)
        raise ChainComAdapterBaseUrlError if base_url.nil?
        raise ChainComAdapterApiKeyIdError if api_key_id.nil?

        @base_url = base_url
        @api_key_id = api_key_id
      end

      # Returns the current balance of the address
      def fetch_balance_for(address)
        api_request("/addresses/#{address}")[0]['total']['balance']
      end

      # Returns transaction info for the tid
      def fetch_transaction(tid, address: nil)
        straighten_transaction api_request("/transactions/#{tid}"), address: address
      end

      # Returns all transactions for the address
      def fetch_transactions_for(address)
        transactions = api_request("/addresses/#{address}/transactions")
        transactions.map { |t| straighten_transaction(t, address: address) }
      end

      private

      def api_request(url)
        conn = Faraday.new("#{@base_url}/#{url}?api-key-id=#{@api_key_id}", ssl: { verify: false }) do |faraday|
          faraday.adapter Faraday.default_adapter
        end
        result = conn.get
        unless result.status == 200
          raise RequestError, "Cannot access remote API, response code was #{result.code}"
        end
        JSON.parse(result.body)
      rescue JSON::ParserError => e
        raise RequestError, YAML::dump(e)
      rescue => e
        raise RequestError, YAML::dump(e)
      end

      # Converts transaction info received from the source into the
      # unified format expected by users of BlockchainAdapter instances.
      def straighten_transaction(transaction, address: nil)
        outs         = []
        total_amount = 0
        transaction['outputs'].each do |out|
          total_amount += out['value'] if address.nil? || address == out['addresses'].first
          outs << { amount: out['value'], receiving_address: out['addresses'].first }
        end

        {
            tid:           transaction['hash'],
            total_amount:  total_amount,
            confirmations: transaction['confirmations'],
            outs:          outs
        }
      end

    end

  end

end
