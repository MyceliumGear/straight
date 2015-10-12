module Straight

  module Blockchain
    # A base class, providing guidance for the interfaces of
    # all blockchain adapters as well as supplying some useful methods.
    class Adapter

      # Raised when blockchain data cannot be retrived for any reason.
      # We're not really intereste in the precise reason, although it is
      # stored in the message.
      class RequestError < StraightError; end

      # Raised when an invalid address is used, for example a mainnet address
      # is used on testnet and vice versa.
      class BitcoinAddressInvalid < StraightError; end

      # How much times try to connect to servers if ReadTimeout error appears
      MAX_TRIES = 5

      def self.support_mainnet?
        raise "Please implement self.support_mainnet? in #{self}"
      end

      def self.support_testnet?
        raise "Please implement self.support_testnet? in #{self}"
      end

      def fetch_transaction(tid)
        raise "Please implement #fetch_transaction in #{self.to_s}"
      end

      def fetch_transactions_for(address)
        raise "Please implement #fetch_transactions_for in #{self.to_s}"
      end

      def fetch_balance_for(address)
        raise "Please implement #fetch_balance_for in #{self.to_s}"
      end

      # Converts transaction info received from the source into the
      # unified format expected by users of BlockchainAdapter instances.
      private def straighten_transaction(transaction)
        raise "Please implement #straighten_transaction in #{self.to_s}"
      end
    end
  end
end
