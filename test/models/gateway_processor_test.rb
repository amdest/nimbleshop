require 'test_helper'

class GatewayProcessorTest <  ActiveRecord::TestCase

  def playcasette(casette)
    transaction = nil

    VCR.use_cassette(casette) do
      transaction = yield
    end

    transaction
  end

  setup do
    @order = create(:order).tap { |t| t.stubs(:total_amount => 100.48) }
    @authorize_net = PaymentMethod.find_by_permalink('authorize-net')
  end

  test "authorization with invalid credit card" do
    creditcard = build(:creditcard, number: 2)
    gateway = GatewayProcessor.new( order: @order, creditcard: creditcard, payment_method: @authorize_net )
    transaction = playcasette('authorize.net/authorize-failure') { gateway.authorize }
    assert transaction.nil?
  end

  test "authorization with valid credit card" do
    creditcard = build :creditcard
    gateway = GatewayProcessor.new( order: @order, creditcard: creditcard, payment_method: @authorize_net )
    transaction = playcasette('authorize.net/authorize-success') { gateway.authorize }

    assert transaction.active?
    assert transaction.authorized?
    assert_equal @order, transaction.order
    assert_equal creditcard, transaction.creditcard
    assert_equal 100.48, transaction.amount.to_f
    assert_equal '2171038291', transaction.transaction_gid
  end

  test 'purchase with invalid credit card' do
    creditcard =   build(:creditcard, number: 2)
    gateway = GatewayProcessor.new( order: @order, creditcard: creditcard, payment_method: @authorize_net )
    transaction = playcasette('authorize.net/purchase-failure') { gateway.purchase }
    assert transaction.nil?
  end

  test 'purchase with valid credit card' do
    creditcard = build :creditcard
    gateway = GatewayProcessor.new( order: @order, creditcard: creditcard, payment_method: @authorize_net )
    transaction = playcasette('authorize.net/purchase-success') { gateway.purchase }
    assert transaction.purchased?
    assert transaction.active?

    assert_equal @order, transaction.order
    assert_equal creditcard, transaction.creditcard
    assert_equal 100.48, transaction.amount
    assert_equal '2171035458', transaction.transaction_gid
  end

  test "capture when credit card is valid" do
    creditcard = build(:creditcard)
    gateway = GatewayProcessor.new( order: @order, creditcard: creditcard, payment_method: @authorize_net )

    authorized = playcasette('authorize.net/authorize-success') do 
      gateway.authorize
    end

    captured = playcasette('authorize.net/capture-success') do
       gateway.capture(authorized)
    end

    refute authorized.reload.active?
    assert captured.captured?
    assert captured.active?
    assert_equal 100.48, captured.amount
    assert_equal '2171038291', captured.transaction_gid
  end

  test "capture when credit card is invalid" do
    creditcard = build(:creditcard)
    gateway = GatewayProcessor.new( order: @order, creditcard: creditcard, payment_method: @authorize_net )
    authorized = playcasette('authorize.net/authorize-success')  { gateway.authorize }
    creditcard.number = 2
    captured   = playcasette('authorize.net/capture-failure')    { gateway.capture(authorized) }

    assert captured.nil?
  end

  test "void when credit card is invalid" do
    creditcard =  build(:creditcard)
    gateway = GatewayProcessor.new( order: @order, creditcard: creditcard, payment_method: @authorize_net )
    authorized = playcasette('authorize.net/authorize-success')  { gateway.authorize }
    creditcard.number = 2
    voided   = playcasette('authorize.net/void-failure')    { gateway.void(authorized) }

    assert voided.nil?
  end

  test "void when credit card is valid" do
    creditcard = build(:creditcard)
    gateway = GatewayProcessor.new( order: @order, creditcard: creditcard, payment_method: @authorize_net )
    authorized = playcasette('authorize.net/void-authorize')  { gateway.authorize }
    voided   = playcasette('authorize.net/void-success')    { gateway.void(authorized) }

    refute authorized.reload.active?
    assert voided.voided?
    assert voided.active?

    assert_equal 100.48, voided.amount
    assert_equal '2171038073', voided.transaction_gid
  end
end