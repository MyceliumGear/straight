module Straight

  # Employs many adapters and runs requests simultaneously.
  # How many adapters are employed is determined by var passed to #initializer (default 2).
  # If all adapters fail it raises an exception.
  class BlockchainAdaptersDispatcher

    class AdaptersTimeoutError < TimeoutError; end
    class AdaptersError < StandardError; end

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

    def run_requests(block)
      execute_in_parallel(block, get_adapters)
      Timeout.timeout(TIMEOUT, AdaptersTimeoutError) {
        @result = @defer_result.wait.value
        raise @defer_result.reason if @defer_result.rejected?
      }
    end
    
  private

    def execute_in_parallel(block, adapters)
      attempts = Concurrent::MVar.new(0)
      pool = Concurrent::ThreadPoolExecutor.new
      adapters.each do |adapter|
        p = Concurrent::Promise.new(executor: pool) { block.call(adapter) }
        p.on_success do |result|
          # Straight.logger "[Straight] Adapter #{adapter} has received result: #{result}"
          @defer_result.set(result)
          pool.kill
        end
        p.rescue do |reason|
          # Straight.logger "[Straight] Adapter #{adapter} got error: #{reason}"
          attempts.modify { |v| v+1 }
          @defer_result.fail(AdaptersError) if finish_iteration?(attempts) && reached_last_adapter?
          execute_in_parallel(block, get_adapters) if finish_iteration?(attempts)
        end
        p.execute
      end
    end

    # Gets specific(@tasks_parallel_limit) quantity of adapters from array of all adapters.
    # Each invocation recalculates position where we're in an array (@list_position)
    # and wich step was used (@step).
    # @return [Array] of adapters for current step 
    def get_adapters
      @step = [adapters.size - @list_position, @tasks_parallel_limit].min
      adapters = @adapters[@list_position...@list_position+@step]
      @list_position += @step
      adapters
    end

    def finish_iteration?(attempts)
      attempts.value == @step
    end

    def reached_last_adapter?
      @list_position == @adapters.size
    end
  end
end
