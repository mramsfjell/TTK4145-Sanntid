defmodule OrderServer.Cost do
  @up_dir [:cab, :hall_up]
  @down_dir [:cab, :hall_down]

  @doc """
  Returns the cost for the lift executing a given order.
  ##Examples
      iex>  OrderServer.Cost.calculate_cost(orders, floor, dir, %Order{} = order)
      int
  """
  def calculate_cost(orders, floor, dir, %Order{} = order) when is_list(orders) do
    order_count = length(orders)
    path = path_length(orders, {floor, dir}, order)
    order_count + path
  end

  @doc """
  Finds the nearest order in the active orders. Returns nil if there are no orders.
  ##Examples
      iex>  OrderServer.Cost.next_order(orders, floor, dir)
      %{floor: floor, dir: dir}

      iex>  OrderServer.Cost.next_order(orders, floor, dir)
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

  @doc """
  Calculates path length by mooving to the extreme points for the path until
  it passes floor where the order is in a valid direction for the order
  """

  def path_length([], {start_floor, _dir}, %{floor: end_floor}) do
    abs(end_floor - start_floor)
  end

  def path_length(
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

  def path_length(
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

  def path_length(_orders, {start_floor, _dir}, %{floor: end_floor}) do
    abs(end_floor - start_floor)
  end
end
