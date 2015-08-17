module Straight

  class StraightError < StandardError; end

  module Blockchain
    class ChainComAdapterBaseUrlError < StraightError
      def message
        'No chain.com adapter base url was found!'
      end
    end
    class ChainComAdapterApiKeyIdError < StraightError
      def message
        'No chain.com adapter API key id was found!'
      end
    end
  end

end
