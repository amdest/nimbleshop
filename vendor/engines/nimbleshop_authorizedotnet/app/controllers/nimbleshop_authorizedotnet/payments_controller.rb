module NimbleshopAuthorizedotnet
  class PaymentsController < ::Admin::PaymentMethodsController

    def create
      order             =  Order.find_by_id(session[:order_id])
      address_attrs     = order.final_billing_address.to_credit_card_attributes
      creditcard_attrs  = params[:creditcard].merge(address_attrs)
      creditcard        = Creditcard.new(creditcard_attrs)
      handler           = NimbleshopAuthorizedotnet::Billing.new(order)

      default_action = Shop.first.default_creditcard_action

      if handler.send(default_action, creditcard: creditcard)
        url = main_app.order_path(order)
        @output = "window.location='#{url}'"
      else
        error = creditcard.errors.full_messages.first
        Rails.logger.info "Error: #{error}"
        @output = "alert('#{error}')"
      end

      respond_to do |format|
        format.js do
          render js: @output
        end
      end

    end

  end
end
