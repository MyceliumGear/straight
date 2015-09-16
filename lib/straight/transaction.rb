module Straight
  Transaction = Struct.new(:tid, :amount, :confirmations, :block_height) do

    def self.from_hash(hash)
      hash          = hash.dup
      hash[:amount] = hash[:total_amount] if hash.key?(:total_amount)
      new(*hash.values_at(*members))
    end

    def self.from_hashes(array)
      array.map { |item| from_hash(item) }
    end
  end
end
