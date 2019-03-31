defmodule OrderServer.Cost do
  @moduledoc """
  The module calculates the cost of a given order.

  The calculation is based on counting the number of orders each lift
  has at the moment, and finding the total path length the lift cab has
  to travel from its current position to the targeted position.

  Uses the following modules:
  - Order
  """

  @up_dir [:cab, :hall_up]
  @down_dir [:cab, :hall_down]

  @doc """
  Returns the cost for the lift executing a given order, given the last floor the lift
  passed and the last direction.

  ##Examples
    iex> import Order
    iex> new_order = Order.new(2,:hall_up)
    iex> OrderServer.Cost.calculate_cost([Order.new(0,:cab), Order.new(1,:hall_down)],2,:down,new_order)
    6
  """

  def calculate_cost(orders, floor, dir, %Order{} = order) when is_list(orders) do
    order_count = length(orders)
    path = path_length(orders, {floor, dir}, order)
    order_count + path
  end

  @doc """
  Finds the nearest order in the active orders. Returns nil if there are no orders.
  """

  def closest_order(orders, floor, dir) when is_list(orders) do
    Enum.min_by(
      orders,
      fn order ->
        path_length(orders, {floor, dir}, order)
      end,
      fn -> nil end
    )
  end

  def closest_order(orders, floor, dir) when is_nil(orders) do
    nil
  end

  @doc """
  General algorithm:
  Find the path length from the start position to the target position along the
  path given by orders, where possition is is given by the floor and valid direction of
  an order
  """

  defp path_length([], {start_floor, _dir}, %{floor: end_floor} = target) do
    abs(end_floor - start_floor)
  end

  defp path_length(
         orders,
         {start_floor, :up},
         %{floor: end_floor, button_type: button} = target
       )
       when start_floor > end_floor or button == :hall_down do
    top_floor =
      Enum.max_by([target | orders], fn order -> order.floor end)
      |> Map.get(:floor)

    abs(top_floor - start_floor) + path_length(orders, {top_floor, :down}, target)
  end

  defp path_length(
         orders,
         {start_floor, :down},
         %{floor: end_floor, button_type: button} = target
       )
       when start_floor < end_floor or button == :hall_up do
    bottom_floor =
      Enum.min_by([target | orders], fn order -> order.floor end)
      |> Map.get(:floor)

    abs(bottom_floor - start_floor) + path_length(orders, {bottom_floor, :up}, target)
  end

  defp path_length(_orders, {start_floor, _dir}, %{floor: end_floor}) do
    abs(end_floor - start_floor)
  end
end
