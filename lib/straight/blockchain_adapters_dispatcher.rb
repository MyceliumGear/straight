module Straight

  # Employs many adapters and runs requests simultaneously.
  # How many adapters are employed is determined by var passed to #initializer (default 2).
  # If all adapters fail it raises an exception.
  class BlockchainAdaptersDispatcher

    class AdaptersTimeoutError < TimeoutError; end

    TIMEOUT = 60
    attr_reader :list_position, :adapters, :result, :defer_result, :step, :tasks_parallel_limit

    def initialize(adapters, tasks_parallel_limit: 2, &block)
      @list_position        = 0
      @defer_result         = Concurrent::IVar.new
      @tasks_parallel_limit = tasks_parallel_limit
      @step                 = 0
      @adapters             = adapters
      run_requests(block) if block_given?
    end

    def get_adapters
      @step = [adapters.size - @list_position, @tasks_parallel_limit].min
      adapters = @adapters[@list_position...@list_position+@step]
      @list_position += @step
      adapters
    end

    def run_requests(block)
      execute_in_parallel(block, get_adapters)
      Timeout::timeout(TIMEOUT, AdaptersTimeoutError) {
        @result = @defer_result.wait.value
      }
    end
    
  private

    def execute_in_parallel(block, adapters)
      attempts = Concurrent::MVar.new(0)
      pool = Concurrent::ThreadPoolExecutor.new
      adapters.each do |adapter|
        p = Concurrent::Promise.new(executor: pool) { block.call(adapter) }
        p.then do |result|
          @defer_result.set(result)
          pool.kill
        end
        p.rescue do |reason|
          raise reason if finish_iteration?(attempts) && reached_last_adapter?
          attempts.modify { |v| v+1 }
          execute_in_parallel(block, get_adapters) if finish_iteration?(attempts)
        end
        p.execute
      end
    end

    def finish_iteration?(attempts)
      attempts.value == @step
    end

    def reached_last_adapter?
      @list_position == @adapter.size
    end
  end
end
