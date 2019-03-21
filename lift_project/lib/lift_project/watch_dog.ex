defmodule WatchDog do
  @moduledoc """
  This module is meant to take care of any order not being handled within
  reasonable time, set by the timer length @watchdog_timer.

  A process starts each time an order's watch_node is set up. If the timer
  of a specific order goes out before the order_complete message is received,
  this order is reinjected to the system by the order distribution logic.
  If everything works as expected, the process is killed when the order_complete
  message is received.



  Use genserver whith list of all assigned orders. Use process.send_after to
  take care of expiered timers. Also handle Node down/up
  """

  use GenServer
  @name :watch_dog
  @watchdog_timer 30_000

  @cab_orders [:cab]
  @hall_orders [:hall_up, :hall_down]

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  # API------------------------------------------------------
  def new_order(order) do
    GenServer.call(@name, {:new_order, order})
  end

  def order_complete(order) do
    GenServer.cast(@name, {:order_complete, order})
  end

  def get_state() do
    GenServer.call(@name, :get)
  end

  # Callbacks-----------------------------------------------------
  def init([]) do
    :net_kernel.monitor_nodes(true)
    state = %{active: %{}, stand_by: %{}}
    {:ok, state}
  end

  def handle_call({:new_order, order}, _from, state) do
    new_state = add_order(state, :active, order)
    Process.send_after(self(), {:order_expiered, order.time}, @watchdog_timer)
    {:reply, :ok, new_state}
  end

  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end

  def handle_cast({:order_complete, order}, state) do
    updated_state = remove_order(state, :active, order)
    {:noreply, updated_state}
  end

  def handle_info({:order_expiered, time_stamp}, state) do
    case get_in(state, [:active, time_stamp]) do
      nil ->
        {:noreply, state}

      order ->
        IO.puts("Order expiered")
        IO.inspect(order)
        reinject_order(order)
        new_state = remove_order(state, :active, order)
        {:noreply, new_state}
    end
  end

  def handle_info({:nodedown, node_name}, state) do
    IO.puts("NODE DOWN#{node_name}")

    with dead_node_orders <- fetch_node(state, node_name),
         cab_orders <- fetch_order_type(dead_node_orders, :cab),
         hall_orders <- fetch_order_type(dead_node_orders, :hall) do
      reinject_order(hall_orders)
      updated_state = moove_to_standby(state, cab_orders)
      IO.inspect(updated_state)
      {:noreply, updated_state}
    else
      _ ->
        IO.puts("error in node down")
        {:noreply, state}
    end
  end

  def handle_info({:nodeup, node_name}, state) do
    standby_orders =
      state
      |> Map.get(:stand_by)
      |> Map.values()
      |> Enum.filter(fn order -> order.node == node_name end)

    reinject_order(standby_orders)
    new_state = remove_order(state, :stand_by, standby_orders)
    {:noreply, new_state}
  end

  def add_order(state, order_state, order) do
    put_in(state, [order_state, order.time], order)
  end

  def remove_order(state, _order_state, []) do
    state
  end

  def remove_order(state, order_state, orders)
      when is_list(orders) do
    Enum.reduce(orders, state, fn order, int_state ->
      IO.inspect({order, int_state})
      remove_order(int_state, order_state, order)
    end)
  end

  def remove_order(state, order_state, %Order{} = order) do
    {_complete, new_state} = pop_in(state, [order_state, order.time])
    new_state
  end

  def fetch_node(state, node_name) do
    state
    |> Map.get(:active)
    |> Map.values()
    |> Enum.filter(fn order -> order.node == node_name end)
  end

  def fetch_order_type(orders, :cab) do
    Enum.filter(orders, fn order -> order.button_type in @cab_orders end)
  end

  def fetch_order_type(orders, :hall) do
    Enum.filter(orders, fn order -> order.button_type in @hall_orders end)
  end

  def reinject_order(orders)
      when is_list(orders) do
    Enum.each(orders, fn order -> reinject_order(order) end)
  end

  def reinject_order(%Order{} = order) do
    IO.inspect(order)
    OrderDistribution.new_order(order)
  end

  def moove_to_standby(state, orders)
      when is_list(orders) do
    Enum.reduce(orders, state, fn order, int_state ->
      moove_to_standby(int_state, order)
    end)
  end

  def moove_to_standby(state, %Order{} = order) do
    new_active =
      state
      |> Map.get(:active)
      |> Map.delete(order.time)

    new_standby =
      state
      |> Map.get(:stand_by)
      |> Map.put(order.time, order)

    # Rebuild map
    IO.inspect(new_active)
    IO.inspect(new_standby)
    %{active: new_active, stand_by: new_standby}
  end
end
