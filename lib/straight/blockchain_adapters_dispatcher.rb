module Straight

  # Employs many adapters and runs requests simultaneously.
  # How many adapters are employed is determined by STEP.
  # If all adapters fail it raises an exception.
  class BlockchainAdaptersDispatcher

    STEP = 2
    attr_reader :list_position, :adapters, :result, :step

    def initialize(adapters, &block)
      @list_position = 0
      @result        = nil
      @step          = 0
      @adapters = adapters
      run_requests(block) if block_given?
    end

    def get_adapters
      @step = [adapters.size - @list_position, STEP].min
      adapters = @adapters[@list_position..@step-1]
      @list_position += @step
      adapters
    end

    def run_requests(block)
      threads = []
      fault_counter = 0
      get_adapters.each do |adapter| 
        t = Thread.new do
          block.call(adapter)
        end
        t.abort_on_exception = true
        threads << t
      end
      wait_values(threads)
    rescue => e
      raise e if fault_counter == @step && @list_position == @adapters.size
      if fault_counter == @step 
        fault_counter = 0
        retry
      end
      fault_counter += 1
    end

    def wait_values(threads)
      threads.each do |t| 
        Thread.new do
          if val = t.value
            @result = val
            threads.map(&:kill)
          end
        end
      end
      loop { break if @result }
      @result
    end

  end
end
