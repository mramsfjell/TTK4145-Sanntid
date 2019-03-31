defmodule WatchDog do
  @moduledoc """
  This module takes care of any order not being handled within reasonable time,
  by resending it to OrderDistribution if the timer runns out before the order is completed.
  Also redistributes hall orders if a node dissapeares from the network, and stores cab orders until the
  node comes back.

  Uses the following modules:
  - OrderDistribution
  - Order
  - FileBackup
  """

  use GenServer
  @name :watch_dog
  @watchdog_timer 20_000
  @backup_file "watchdog_backup.txt"

  @cab_orders [:cab]
  @hall_orders [:hall_up, :hall_down]

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  # API-------------------------------------------------------------------------

  @doc """
  Synchronous call adding a new order. Replies :ok as an accnowledgement
  """
  def new_order(order) do
    GenServer.call(@name, {:new_order, order})
  end

  @doc """
  Sends message to the module that an order is completed.
  """
  def order_complete(order) do
    GenServer.cast(@name, {:order_complete, order})
  end

  @doc """
  Gets the current state of the watchdog, used for debugging purpouses
  """
  def get_state() do
    GenServer.call(@name, :get)
  end

  # Callbacks-------------------------------------------------------------------
  def init([]) do
    :net_kernel.monitor_nodes(true)
    state = read_from_backup(@backup_file)
    {:ok, state}
  end

  def handle_call({:new_order, order}, _from, state) do
    new_state =
      state
      |> add_order(:active, order)
      |> start_timer(order)

    FileBackup.write(new_state, @backup_file)
    {:reply, :ok, %{} = new_state}
  end

  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end

  def handle_cast({:order_complete, order}, state) do
    updated_state =
      state
      |> stop_timer(order)
      |> remove_order(:active, order)

    FileBackup.write(updated_state, @backup_file)
    {:noreply, %{} = updated_state}
  end

  def handle_info({:order_expiered, id}, state) do
    case get_in(state, [:active, id]) do
      nil ->
        {:noreply, state}

      order ->
        reinject_order(order)

        new_state =
          state
          |> remove_order(:timers, order)
          |> remove_order(:active, order)

        FileBackup.write(new_state, @backup_file)
        {:noreply, %{} = new_state}
    end
  end

  def handle_info({:nodedown, node_name}, state) do
    IO.puts("NODE DOWN#{node_name}")
    {:ok, dead_node_orders} = fetch_node(state, node_name)
    {:ok, cab_orders} = fetch_order_type(dead_node_orders, :cab)
    {:ok, hall_orders} = fetch_order_type(dead_node_orders, :hall)
    reinject_order(hall_orders)

    updated_state =
      state
      |> stop_timer(cab_orders)
      |> stop_timer(hall_orders)
      |> move_to_standby(cab_orders)
      |> remove_order(:active, hall_orders)

    FileBackup.write(updated_state, @backup_file)
    {:noreply, %{} = updated_state}
  end

  def handle_info({:nodeup, node_name}, state) do
    standby_orders =
      state
      |> Map.get(:standby)
      |> Map.values()
      |> Enum.filter(fn order -> order.node == node_name end)

    reinject_order(standby_orders)
    new_state = remove_order(state, :standby, standby_orders)
    FileBackup.write(new_state, @backup_file)
    {:noreply, %{} = new_state}
  end

  # Helper functions -----------------------------------------------------------
  defp add_order(state, order_state, order) do
    put_in(state, [order_state, order.id], order)
  end

  defp remove_order(state, _order_state, []) do
    state
  end

  defp remove_order(state, order_state, orders) when is_list(orders) do
    Enum.reduce(orders, state, fn order, int_state ->
      remove_order(int_state, order_state, order)
    end)
  end

  defp remove_order(state, order_state, %Order{} = order) do
    {_complete, new_state} = pop_in(state, [order_state, order.id])
    new_state
  end

  defp fetch_node(state, node_name) do
    node_orders =
      state
      |> Map.get(:active)
      |> Map.values()
      |> Enum.filter(fn order -> order.node == node_name end)

    {:ok, node_orders}
  end

  defp fetch_order_type(orders, :cab) do
    {:ok, Enum.filter(orders, fn order -> order.button_type in @cab_orders end)}
  end

  defp fetch_order_type(orders, :hall) do
    {:ok, Enum.filter(orders, fn order -> order.button_type in @hall_orders end)}
  end

  defp reinject_order(orders) when is_list(orders) do
    Enum.each(orders, fn order -> reinject_order(order) end)
  end

  defp reinject_order(%Order{} = order) do
    OrderDistribution.new_order(order)
  end

  defp move_to_standby(state, orders)
       when is_list(orders) do
    Enum.reduce(orders, state, fn order, int_state ->
      move_to_standby(int_state, order)
    end)
  end

  defp move_to_standby(state, %Order{} = order) do
    new_active =
      state
      |> Map.get(:active)
      |> Map.delete(order.id)

    new_standby =
      state
      |> Map.get(:standby)
      |> Map.put(order.id, order)

    state
    |> Map.put(:active, new_active)
    |> Map.put(:standby, new_standby)
  end

  defp read_from_backup(filename) do
    case FileBackup.read(filename) do
      {:ok, backup_state} ->
        active = filter_recent_orders(backup_state, :active, 120)
        standby = filter_recent_orders(backup_state, :standby, 10 * 60)

        state = %{active: active, standby: standby, timers: %{}}

        state =
          Enum.reduce(
            active,
            state,
            fn {_id, order}, int_state -> start_timer(int_state, order) end
          )

        FileBackup.write(state, @backup_file)
        state

      {:error, _} ->
        state = %{active: %{}, standby: %{}, timers: %{}}
    end
  end

  defp filter_recent_orders(state, order_state, time) do
    state
    |> Map.get(order_state)
    |> Map.values()
    |> Enum.filter(fn order ->
      Time.diff(Time.utc_now(), order.time) <= time
    end)
    |> Map.new(fn order -> {order.id, order} end)
  end

  defp start_timer(%{} = state, %Order{} = order) do
    timer = Process.send_after(self(), {:order_expiered, order.id}, @watchdog_timer)
    put_in(state, [:timers, order.id], timer)
  end

  defp stop_timer(state, orders) when is_list(orders) do
    Enum.reduce(orders, state, fn order, int_state -> stop_timer(int_state, order) end)
  end

  defp stop_timer(state, %Order{} = order) do
    {timer, new_state} = pop_in(state, [:timers, order.id])

    if timer != nil do
      Process.cancel_timer(timer)
    end

    new_state
  end
end
