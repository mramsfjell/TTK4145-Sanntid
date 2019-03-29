defmodule OrderState do
  import Order

  @doc ~S"""
  Add the given order(s) to the given order state map.

  ## Examples
    iex> import Order
    iex> order = Order.new(2,:hall_up)
    iex> state = %{active: %{}}
    iex> new_state = OrderState.add_(state,:active,order)
    iex> new_state == %{active: %{order.id => order}}
    true
  """
  @spec add(map, term, list | Order.t()) :: map
  def add(data, order_state, orders) when is_map(data) and is_list(orders) do
    Enum.reduce(
      orders,
      data,
      fn order -> add(data, order_state, order) end
    )
  end

  def add(data, order_state, %Order{} = order) when is_map(data) do
    put_in(data, [order_state, order.id], order)
  end

  @doc ~S"""
  Removes the given order(s) from the given order state map.

  ##Examples
    iex> import Order
    iex> order = Order.new(2,:hall_up)
    iex> state = %{active: %{order.id => order}}
    iex> OrderState.remove(state,:active,order)
    %{active: %{}}


  """
  @spec remove(map, term, list | Order.t()) :: map
  def remove(data, order_state, orders) when is_map(data) and is_list(orders) do
    Enum.reduce(
      orders,
      data,
      fn order -> remove(data, order_state, order) end
    )
  end

  def remove(data, order_state, %Order{} = order) when is_map(data) do
    {_complete_order, new_state} = pop_in(data, [order_state, order.id])
    new_state
  end

  @doc ~S"""
    Moove the given order(s) from one state to another in the given state map

    Examples #
    iex> import Order
    iex> order = Order.new(2,:hall_up)
    iex> state = %{active: %{order.id => order},complete: %{}}
    iex> new_state = OrderState.update(state,:active,:complete,[order])
    iex> new_state == %{active: %{},complete: %{order.id => order}}
    true
  """
  @spec remove(map, term, list | Order.t()) :: map
  def update(data, from_state, to_state, %Order{} = order) when is_map(data) do
    data
    |> add(to_state, order)
    |> remove(from_state, order)
  end

  def update(data, from_state, to_state, orders) when is_map(data) and is_list(orders) do
    data
    |> add(to_state, orders)
    |> remove(from_state, orders)
  end

  @doc ~S"""
    Return a list of orders from the given order state where where the filter_function returns a truty value
    iex> import Order
    iex> order1 = Order.new(2,:hall_up)
    iex> order2 = Order.new(1,:hall_up)
    iex> filter_function = fn -> (order,floor) -> order.floor == floor end
    iex> state = %{active: %{order.id => order},complete: %{}}
    iex> result = OrderState.fetch(state,:active,filter_function,[1])
    iex> result == order1
    true
  """
  @spec fetch(map, term, (Order.t(), any() -> boolean), term()) :: list
  def fetch(data, order_state, filter_funtion, filter_args)
      when is_map(data) and is_function(filter_funtion) do
    data
    |> Map.get(order_state)
    |> Map.values()
    |> Enum.filter(fn order -> filter_funtion.(order, filter_args) end)
  end
end
