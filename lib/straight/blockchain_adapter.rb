module Straight

  module Blockchain
    # A base class, providing guidance for the interfaces of
    # all blockchain adapters as well as supplying some useful methods.
    class Adapter

      include Singleton

      # Raised when blockchain data cannot be retrived for any reason.
      # We're not really intereste in the precise reason, although it is
      # stored in the message.
      class RequestError < StraightError; end

      # Raised when an invalid address is used, for example a mainnet address
      # is used on testnet and vice versa.
      class BitcoinAddressInvalid < StraightError; end

      def fetch_transaction(tid)
        raise "Please implement #fetch_transaction in #{self.to_s}"
      end

      def fetch_transactions_for(address)
        raise "Please implement #fetch_transactions_for in #{self.to_s}"
      end

      def fetch_balance_for(address)
        raise "Please implement #fetch_balance_for in #{self.to_s}"
      end

      private

        # Converts transaction info received from the source into the
        # unified format expected by users of BlockchainAdapter instances.
        def straighten_transaction(transaction)
          raise "Please implement #straighten_transaction in #{self.to_s}"
        end

    end

    # Look for the adapter without namespace if not found it in a specific module
    # @return nil
    def self.const_missing(name)
      Kernel.const_get(name)
    rescue NameError
      puts "WARNING: No blockchain adapter with the name #{name.to_s} was found!"
      nil
    end

  end
end
