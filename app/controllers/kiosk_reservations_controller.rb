# frozen_string_literal: true

# Mostly copied over from ReservationsController, making some
# changes as needed to fit the use case of the Kiosk View page.
# The Kiosk View page provides easy access to commonly used
# reservation actions, saving some clicks for the user.
# The user should be prompted to login before action is taken,
# then logged out and redirected back to the Kiosk View.
class KioskReservationsController < ApplicationController

  before_action :check_acting_as, only: [:switch_instrument]
  before_action :load_and_check_resources, except: [:index]

  include ReservationSwitch

  def index
    sign_out if params[:sign_out].present?
    schedules = current_facility.schedules_for_timeline(:public_instruments)
    instrument_ids = schedules.flat_map { |schedule| schedule.public_instruments.map(&:id) }
    @reservations = Reservation.for_timeline(Time.current.beginning_of_day, instrument_ids)
  end

  def begin
    @switch = "on"
    render layout: false
  end

  def stop
    @switch = "off"
    render layout: false
  end

  # GET /orders/:order_id/order_details/:order_detail_id/kiosk_reservations/switch_instrument
  def switch_instrument
    if can_switch? && switch_value_present?
      switch_instrument!(params[:switch])
      head :ok
    elsif can_switch?
      respond_error(text("switch.error"))
    else
      respond_error(text("authentication.error"))
    end
  end

  private

  def can_switch?
    password = params.dig(:kiosk_reservations, :password)
    kiosk_user = Users::AuthChecker.new(@reservation.user, password)
    kiosk_user.authenticated? && kiosk_user.authorized?(:start_stop, @reservation)
  end

  def load_basic_resources
    @order = Order.find(params[:order_id])
    # It's important that the order_detail be the same object as the one in @order.order_details.first
    @order_detail = @order.order_details.find { |od| od.id.to_i == params[:order_detail_id].to_i }
    raise ActiveRecord::RecordNotFound if @order_detail.blank?
    @reservation = @order_detail.reservation
    @instrument = @order_detail.product
    @facility = @instrument.facility
  rescue ActiveRecord::RecordNotFound
    flash[:error] = text("order_detail_removed")
    if @order
      redirect_to action: :index
    else
      raise
    end
  end

  def load_and_check_resources
    load_basic_resources
    raise ActiveRecord::RecordNotFound if @reservation.blank?
  end

  def ability_resource
    if action_name == "index"
      current_facility
    else
      @reservation
    end
  end

  def respond_error(message)
    @switch = params[:switch]
    flash[:error] = message
    render :begin, status: 406, layout: false
  end

end
