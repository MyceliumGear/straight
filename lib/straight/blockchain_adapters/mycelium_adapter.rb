module Straight
  module Blockchain

    class MyceliumAdapter < Adapter

      MAINNET_SERVERS     = %w{
        https://mws2.mycelium.com/wapi/wapi
        https://mws6.mycelium.com/wapi/wapi
        https://mws7.mycelium.com/wapi/wapi
      }
      TESTNET_SERVERS     = %w{
        https://node3.mycelium.com/wapitestnet/wapi
      }
      PINNED_CERTIFICATES = %w{
        6afe0e9b6806fa4a49fc6818512014332953f30101dad7b91e76c14e073c3134
      }.to_set

      def self.support_mainnet?
        true
      end

      def self.support_testnet?
        true
      end

      def self.mainnet_adapter
        new(testnet: false)
      end

      def self.testnet_adapter
        new(testnet: true)
      end

      def initialize(testnet: false)
        @latest_block = { cache_timestamp: nil, block: nil }
        @testnet = testnet
        @api_servers = @testnet ? TESTNET_SERVERS : MAINNET_SERVERS
        set_base_url
      end

      def testnet?
        @testnet
      end

      # Set url for API request.
      # @param num [Integer] a number of server in array
      def set_base_url(num = 0)
        return nil if num >= @api_servers.size
        @base_url = @api_servers[num]
      end

      def next_server
        set_base_url(@api_servers.index(@base_url) + 1)
      end

      # Returns transaction info for the tid
      def fetch_transaction(tid, address: nil)
        transaction = api_request('getTransactions', { txIds: [tid] })['transactions'].first
        straighten_transaction transaction, address: address
      end

      # Supposed to returns all transactions for the address, but
      def fetch_transactions_for(address)
        # API may return nil instead of an empty array if address turns out to be invalid
        # (for example when trying to supply a testnet address instead of mainnet while using
        # mainnet adapter.
        if api_response = api_request('queryTransactionInventory', {addresses: [address], limit: 100})
          (api_response['txIds'] || []).map { |tid| fetch_transaction(tid, address: address) }
        else
          raise BitcoinAddressInvalid, message: "address in question: #{address}"
        end
      end

      # Returns the current balance of the address
      def fetch_balance_for(address)
        unspent = 0
        api_request('queryUnspentOutputs', { addresses: [address]})['unspent'].each do |out|
          unspent += out['value']
        end
        unspent
      end

      def latest_block(force_reload: false)
        # If we checked Blockchain.info latest block data
        # more than a minute ago, check again. Otherwise, use cached version.
        if @latest_block[:cache_timestamp].nil?              ||
           @latest_block[:cache_timestamp] < (Time.now - 60) ||
           force_reload
          @latest_block = {
            cache_timestamp: Time.now,
            block: api_request('queryUnspentOutputs', { addresses: []} )
          }
        else
          @latest_block
        end
      end

      def latest_block_height(force_reload: false)
        latest_block(force_reload: force_reload)[:block]['height']
      end

      private

        def api_request(method, params={})
          ssl_opts =
            if testnet?
              {verify: false}
            else
              {verify_callback: lambda { |preverify_ok, store_context|
                end_cert = store_context.chain[0] # pinned invalid certificate
                PINNED_CERTIFICATES.include?(OpenSSL::Digest::SHA256.hexdigest(end_cert.to_der)) || preverify_ok
              }}
            end
          begin
            conn = Faraday.new(url: "#{@base_url}/#{method}", ssl: ssl_opts) do |faraday|
              faraday.request  :url_encoded             # form-encode POST params
              faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
            end
            result = conn.post do |req|
              req.body = params.merge({version: 1}).to_json
              req.headers['Content-Type'] = 'application/json'
            end
            JSON.parse(result.body || '')['r']
          rescue => e
            next_server ? retry : raise(RequestError, YAML::dump(e))
          end
        end

        # Converts transaction info received from the source into the
        # unified format expected by users of BlockchainAdapter instances.
        def straighten_transaction(transaction, address: nil)
          # Get the block number this transaction was included into
          block_height = transaction['height']
          tid          = transaction['txid']

          # Converting from Base64 to binary
          transaction = transaction['binary'].unpack('m0')[0]

          # Decoding
          transaction = BTC::Transaction.new(data: transaction)

          outs         = []
          total_amount = 0

          transaction.outputs.each do |out|
            amount = out.value
            receiving_address = out.script.standard_address
            total_amount += amount if address.nil? || address == receiving_address.to_s
            outs << {amount: amount, receiving_address: receiving_address}
          end

          {
            tid:           tid,
            total_amount:  total_amount.to_i,
            confirmations: calculate_confirmations(block_height),
            block_height:  block_height,
            outs:          outs,
            meta: {
              fetched_via: self,
            },
          }
        end

        # When we call #calculate_confirmations, it doesn't always make a new
        # request to the blockchain API. Instead, it checks if cached_id matches the one in
        # the hash. It's useful when we want to calculate confirmations for all transactions for
        # a certain address without making any new requests to the Blockchain API.
        def calculate_confirmations(block_height, force_latest_block_reload: false)

          if block_height && block_height != -1
            latest_block_height(force_reload: force_latest_block_reload) - block_height + 1
          else
            0
          end

        end

    end

  end
end
