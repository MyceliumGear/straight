module Straight

  # This module should be included into your own class to extend it with Order functionality.
  # For example, if you have a ActiveRecord model called Order, you can include OrderModule into it
  # and you'll now be able to do everything to check order's status, but you'll also get AR Database storage
  # funcionality, its validations etc.
  #
  # The right way to implement this would be to do it the other way: inherit from Straight::Order, then
  # include ActiveRecord, but at this point ActiveRecord doesn't work this way. Furthermore, some other libraries, like Sequel,
  # also require you to inherit from them. Thus, the module.
  #
  # When this module is included, it doesn't actually *include* all the methods, some are prepended (see Ruby docs on #prepend).
  # It is important specifically for getters and setters and as a general rule only getters and setters are prepended.
  #
  # If you don't want to bother yourself with modules, please use Straight::Order class and simply create new instances of it.
  # However, if you are contributing to the library, all new funcionality should go to either Straight::OrderModule::Includable or
  # Straight::OrderModule::Prependable (most likely the former).
  module OrderModule

    # Only add getters and setters for those properties in the extended class
    # that don't already have them. This is very useful with ActiveRecord for example
    # where we don't want to override AR getters and setters that set attribtues.
    def self.included(base)
      base.class_eval do
        %i{
          accepted_transactions
          address
          amount
          amount_paid
          amount_with_currency
          block_height_created_at
          callback_url
          gateway
          keychain_id
          status
          test_mode
          tid
          title
        }.each do |field|
          attr_reader field unless base.method_defined?(field)
          attr_writer field unless base.method_defined?("#{field}=")
        end
        prepend Prependable
        include Includable
      end
    end

    # Worth noting that statuses above 1 are immutable. That is, an order status cannot be changed
    # if it is more than 1. It makes sense because if an order is paid (5) or expired (2), nothing
    # else should be able to change the status back. Similarly, if an order is overpaid (4) or
    # underpaid (5), it requires admin supervision and possibly a new order to be created.
    STATUSES = {
      new:          0, # no transactions received
      unconfirmed:  1, # transaction has been received doesn't have enough confirmations yet
      paid:         2, # transaction received with enough confirmations and the correct amount
      underpaid:    3, # amount that was received in a transaction was not enough
      overpaid:     4, # amount that was received in a transaction was too large
      expired:      5, # too much time passed since creating an order
      canceled:     6, # user decides to economize
      partially_paid: -3, # mutable, becomes underpaid or paid/overpaid
    }

    attr_reader :old_status

    class IncorrectAmount < StraightError; end

    # If you are defining methods in this module, it means you most likely want to
    # call super() somehwere inside those methods. An example would be the #status=
    # setter. We do our thing, then call super() so that the class this module is prepended to
    # could do its thing. For instance, if we included it into ActiveRecord, then after
    # #status= is executed, it would call ActiveRecord model setter #status=
    #
    # In short, the idea is to let the class we're being prepended to do its magic
    # after out methods are finished.
    module Prependable

      # Checks #transaction and returns one of the STATUSES based
      # on the meaning of each status and the contents of transaction
      # If as_sym is set to true, then each status is returned as Symbol, otherwise
      # an equivalent Integer from STATUSES is returned.
      def status(as_sym: false, reload: false)

        if defined?(super)
          begin
            @status = super
          # if no method with arguments found in the class
          # we're prepending to, then let's use a standard getter
          # with no argument.
          rescue ArgumentError
            @status = super()
          end
        end

        # Prohibit status update if the order was paid in some way.
        # This is just a caching workaround so we don't query
        # the blockchain needlessly. The actual safety switch is in the setter.
        if (reload || @status.nil?) && !status_locked?
          result = get_transaction_status(reload: reload)
          result.each { |k, v| send :"#{k}=", v }
        end

        as_sym ? STATUSES.invert[@status] : @status
      end

      def status=(new_status)
        # Prohibit status update if the order was paid in some way,
        # so statuses above 1 are in fact immutable.
        return false if status_locked?

        # Pay special attention to the order of these statements. If you place
        # the assignment @status = new_status below the callback call,
        # you may get a "Stack level too deep" error if the callback checks
        # for the status and it's nil (therefore, force reload and the cycle continues).
        #
        # The order in which these statements currently are prevents that error, because
        # by the time a callback checks the status it's already set.
        @status_changed = (@status != new_status)
        @old_status     = @status
        @status         = new_status
        gateway.order_status_changed(self) if status_changed?
        super if defined?(super)
      end

      def get_transaction_status(reload: false, transactions: nil)
        transactions ||=
          if block_height_created_at.to_i > 0
            transactions_since(reload: reload)
          else
            [transaction(reload: reload)]
          end.compact

        uniq_transactions = transactions.uniq(&:tid)
        amount_paid       = uniq_transactions.map(&:amount).reduce(:+) || 0

        if !uniq_transactions.empty? && amount_paid <= 0
          Straight.logger.warn "Strange transactions for address #{address}: #{uniq_transactions.inspect}"
          amount_paid = 0
        end

        status =
          if amount_paid > 0
            if (gateway.donation_mode || (amount == 0) || (amount > 0 && amount_paid >= amount)) && status_unconfirmed?(uniq_transactions)
              STATUSES.fetch(:unconfirmed)
            elsif gateway.donation_mode || (amount == 0) || (amount > 0 && amount_paid == amount)
              STATUSES.fetch(:paid)
            elsif amount_paid < amount
              STATUSES.fetch(:partially_paid)
            elsif amount_paid > amount
              STATUSES.fetch(:overpaid)
            end
          else
            STATUSES.fetch(:new)
          end

        {amount_paid: amount_paid, accepted_transactions: uniq_transactions, status: status}
      end

      def status_unconfirmed?(transactions)
        confirmations = transactions.map { |t| t.confirmations }.compact.min.to_i
        confirmations < gateway.confirmations_required
      end

      def status_locked?
        @status && @status > 1
      end

      def status_changed?
        @status_changed
      end

      # @deprecated
      def tid
        (respond_to?(:[]) ? self[:tid] : @tid) || begin
          tids = (accepted_transactions || []).map { |t| t[:tid] }.join(',')
          tids.empty? ? nil : tids
        end
      end

    end

    module Includable

      # Returns an array of transactions for the order's address, each as a hash:
      #   [ {tid: "feba9e7bfea...", amount: 1202000, ...} ]
      #
      # An order is supposed to have only one transaction to its address, but we cannot
      # always guarantee that (especially when a merchant decides to reuse the address
      # for some reason -- he shouldn't but you know people).
      #
      # Therefore, this method returns all of the transactions.
      # For compliance, there's also a #transaction method which always returns
      # the last transaction made to the address.
      def transactions(reload: false)
        @transactions = nil if reload
        @transactions ||= begin
          hashes = gateway.fetch_transactions_for(address)
          Straight::Transaction.from_hashes(hashes)
        end
      end

      # Last transaction made to the address. Always use this method to check whether a transaction
      # for this order has arrived. We pick last and not first because an address may be reused and we
      # always assume it's the last transaction that we want to check.
      def transaction(reload: false)
        transactions(reload: reload).first
      end

      # Returns an array of transactions for the order's address, which were created after the order
      def transactions_since(block_height: block_height_created_at, reload: false)
        transactions(reload: reload).select { |t| t.block_height.to_i <= 0 || t.block_height > block_height }
      end

      # Starts a loop which calls #status(reload: true) according to the schedule
      # determined in @status_check_schedule. This method is supposed to be
      # called in a separate thread, for example:
      #
      #   Thread.new do
      #     order.start_periodic_status_check
      #   end
      #
      # `duration` argument (value is in seconds) allows you to
      # control in what time an order expires. In other words, we
      # keep checking for new transactions until the time passes.
      # Then we stop and set Order's status to STATUS[:expired]. See
      # #check_status_on_schedule for the implementation details.
      def start_periodic_status_check(duration: 600)
        check_status_on_schedule(duration: duration)
      end

      # Recursion here! Keeps calling itself according to the schedule until
      # either the status changes or the schedule tells it to stop.
      def check_status_on_schedule(period: 10, iteration_index: 0, duration: 600, time_passed: 0)
        status_reload_started = Time.now.to_f
        self.status(reload: true)
        Straight.logger.info "Order #{respond_to?(:id) ? id : object_id} has status #{@status}; checking took #{(-status_reload_started + Time.now.to_f).round(3)} seconds"
        time_passed += period
        if duration >= time_passed # Stop checking if status is >= 2
          if self.status < 2
            schedule = gateway.status_check_schedule.call(period, iteration_index)
            sleep period
            check_status_on_schedule(
              period:          schedule[:period],
              iteration_index: schedule[:iteration_index],
              duration:        duration,
              time_passed:     time_passed
            )
          end
        elsif self.status == -3
          self.status = 3
        # elsif self.status == 1
        #   TODO: orders with unconfirmed transactions should not expire
        elsif self.status < 2
          self.status = STATUSES[:expired]
        end
      end

      def to_json
        to_h.to_json
      end

      def to_h
        {
          status: status,
          amount: amount,
          address: address,
          tid: tid, # @deprecated
          transaction_ids: (accepted_transactions || []).map(&:tid),
        }
      end

      def amount_in_btc(field: amount, as: :number)
        a = Satoshi.new(field, from_unit: :satoshi, to_unit: :btc)
        as == :string ? a.to_unit(as: :string) : a.to_unit
      end

    end

  end

  # Instances of this class are generated when we'd like to start watching
  # some addresses to check whether a transaction containing a certain amount
  # has arrived to it.
  #
  # It is worth noting that instances do not know how store themselves anywhere,
  # so as the class is written here, those instances are only supposed to exist
  # in memory. Storing orders is entirely up to you.
  class Order
    include OrderModule

    def initialize
      @status = 0
    end

  end

end
