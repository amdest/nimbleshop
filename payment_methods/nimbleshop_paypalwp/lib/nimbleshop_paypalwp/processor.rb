module NimbleshopPaypalwp
  class Processor < Processor::Base

    attr_reader :order, :payment_method, :notify

    def initialize(options = {})
      @notify = ActiveMerchant::Billing::Integrations::Paypal::Notification.new(options[:raw_post])
      @order = Order.find_by_number!(notify.invoice)
      @payment_method = NimbleshopPaypalwp::Paypalwp.first
    end

    private

    def do_capture(options = {})
      success = amount_match?
      record_transaction('captured', success: success)

      if success
        order.update_attributes(purchased_at: purchased_at, payment_method: payment_method)
        order.kapture
      end

      success
    end

    def do_authorize(options = {})
      success = amount_match?
      record_transaction('authorized', success: success)

      if success
        order.update_attributes(purchased_at: purchased_at, payment_method: payment_method)
        order.authorize
      end

      success
    end

    def do_void(options = {})
    end

    def do_purchase(options = {})
      if success = ipn_from_paypal?
        record_transaction('purchased', success: success)
        order.update_attributes(purchased_at: notify.received_at, payment_method: payment_method)
        order.purchase
      end

      success
    end

    def record_transaction(operation, options = {})
      order.payment_transactions.create(options.merge(amount: notify.amount.cents,
                                                      params: { ipn: notify.raw },
                                                      transaction_gid: notify.transaction_id,
                                                      operation: operation))

    end

    def ipn_from_paypal?
      amount_match? && notify.complete? && business_email_match?
    end

    def business_email_match?
      notify.account ==  payment_method.merchant_email
    end

    def amount_match?
      notify.amount.cents == order.total_amount_in_cents
    end

    def purchased_at
      Time.strptime(notify.params['payment_date'], "%H:%M:%S %b %d, %Y %z")
    end
  end
end
