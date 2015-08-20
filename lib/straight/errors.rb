module Straight

  class StraightError < StandardError; end

  module Blockchain
    class ChainComAdapterApiKeyIdError < StraightError
      def message
        'No chain.com adapter API key id was found!'
      end
    end
  end

end
