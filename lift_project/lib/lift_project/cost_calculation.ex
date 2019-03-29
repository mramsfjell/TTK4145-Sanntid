defmodule OrderServer.Cost do
  @moduledoc """
  The module calculates the cost of a given order, using 

  Uses the following modules:
  - Order
  """

  @up_dir [:cab, :hall_up]
  @down_dir [:cab, :hall_down]

  @doc """
  Returns the cost for the lift executing a given order, given the last floor the lift
  passed and the last direction.
  ##Examples
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
  ##Examples
    iex> order1 = Order.new(1,:cab)
    iex> order2 = Order.new(2,:hall_down)
    iex> orders = [order1,order2]
    iex> next_order = OrderServer.Cost.next_order(orders, 0, :up)
    iex> order1 == next_order
    true

    iex> next_order = OrderServer.Cost.next_order([], 0, :up)
    nil
  """

  def next_order(orders, floor, dir) when is_list(orders) do
    Enum.min_by(
      orders,
      fn order ->
        path_length(orders, {floor, dir}, order)
      end,
      fn -> nil end
    )
  end

  def next_order(orders, floor, dir) when is_nil(orders) do
    nil
  end

  @doc """
  General algorithm:
  Find the path length from the start possition to the target possition along the
  path given by orders

  If there are no orders, the path is the distance between the current floor and
  the target floor.
  """
  defp path_length([], {start_floor, _dir}, %{floor: end_floor} = target_order) do
    abs(end_floor - start_floor)
  end

  @doc """
  When the elevator is mooving up, and the order is below, or is :hall_down the
  algorithm finds the top order and calculates the path to the order from there
  """
  defp path_length(
         orders,
         {start_floor, :up},
         %{floor: end_floor, button_type: button} = target_order
       )
       when start_floor > end_floor or button == :hall_down do
    top_floor =
      Enum.max_by(
        [target_order | orders],
        fn order -> order.floor end
      )
      |> Map.get(:floor)

    abs(top_floor - start_floor) + path_length(orders, {top_floor, :down}, target_order)
  end

  @doc """
  When the elevator is mooving down, and the order is above, or is :hall_upthe
  algorithm finds the lowest order and calculates the path to the order from there
  """
  defp path_length(
         orders,
         {start_floor, :down},
         %{floor: end_floor, button_type: button} = target_order
       )
       when start_floor < end_floor or button == :hall_up do
    bottom_floor =
      Enum.min_by(
        [target_order | orders],
        fn order -> order.floor end
      )
      |> Map.get(:floor)

    abs(bottom_floor - start_floor) +
      path_length(orders, {bottom_floor, :up}, target_order)
  end

  @doc """
  If the above clauses does not match the distance can be calculated as the
  distance between the target floor and the current floor
  """
  defp path_length(_orders, {start_floor, _dir}, %{floor: end_floor}) do
    abs(end_floor - start_floor)
  end
end
