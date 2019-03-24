defmodule Order do
  @moduledoc """
  Defining the data structure for, and creation of a order. The timestamp is used as an order ID.
  """

  @up_dir [:cab, :hall_up]
  @down_dir [:cab, :hall_down]
  @valid_order [:hall_down, :cab, :hall_up]
  @enforce_keys [:floor, :button_type]
  defstruct [:floor, :button_type, :id, :time, node: nil, watch_dog: nil]

  def new(floor, button_type)
      when is_integer(floor) and button_type in @valid_order do
    %Order{
      floor: floor,
      button_type: button_type,
      id: make_ref(),
      time: Time.utc_now() |> Time.truncate(:seconds),
      node: Node.self()
    }
  end

  def order_at_floor?(%Order{} = order, floor, :up) do
    order.floor == floor and order.button_type in @up_dir
  end

  def order_at_floor?(%Order{} = order, floor, :down) do
    order.floor == floor and order.button_type in @down_dir
  end

  def order_at_floor?(%Order{} = order, floor) do
    order.floor == floor
  end
end
