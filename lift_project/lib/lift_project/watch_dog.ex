defmodule WatchDog do
  @moduledoc """
  This module is meant to take care of any order not being handled within
  reasonable time, set by the timer length @watchdog_timer.

  A process starts each time an order's watch_node is set up. If the timer
  of a specific order goes out before the order_complete message is received,
  this order is reinjected to the system by the order distribution logic.
  If everything works as expected, the process is killed when the order_complete
  message is received.

  Use GenServer whith list of all assigned orders. Use process.send_after to
  take care of expired timers. Also handle Node down/up
  """

  use GenServer
  @name :watch_dog
  @watchdog_timer 30_000
  @backup_file "watchdog_backup.txt"

  @cab_orders [:cab]
  @hall_orders [:hall_up, :hall_down]

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  # API-------------------------------------------------------------------------

  @doc """
  Calls that a new order is added and sets the watchdog timer. If order not
  completed within @watchdog_timer, the order is reinjected.
  """
  def new_order(order) do
    GenServer.call(@name, {:new_order, order})
  end

  @doc """
  Casts that an order is completed and kills the watchdog process.
  """
  def order_complete(order) do
    GenServer.cast(@name, {:order_complete, order})
  end

  @doc """
  Gets the current state of the orders. Returns a map of the states and the orders
  affiliated with the given state. Stand_by is the state of cab calls from
  dead nodes. Active is the state of running nodes.
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
    new_state = add_order(state, :active, order)
    Process.send_after(self(), {:order_expiered, order.id}, @watchdog_timer)
    FileBackup.write(new_state, @backup_file)
    {:reply, :ok, new_state}
  end

  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end

  def handle_cast({:order_complete, order}, state) do
    updated_state = remove_order(state, :active, order)
    FileBackup.write(updated_state, @backup_file)
    {:noreply, updated_state}
  end

  def handle_info({:order_expiered, time_stamp}, state) do
    case get_in(state, [:active, time_stamp]) do
      nil ->
        {:noreply, state}

      order ->
        IO.puts("Order expired")
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
      updated_state = move_to_standby(state, cab_orders)
      IO.inspect(updated_state)
      FileBackup.write(updated_state, @backup_file)
      {:noreply, updated_state}
    else
      _ ->
        IO.puts("Error in node down")
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
    FileBackup.write(new_state, @backup_file)
    {:noreply, new_state}
  end

  # Helper functions -----------------------------------------------------------

  @doc """
  Adds an order with its affiliated state to the state map.
  """
  def add_order(state, order_state, order) do
    put_in(state, [order_state, order.id], order)
  end

  @doc """
  Edge case when trying to remove an order from the state map when there
  are no orders in the map.
  """
  def remove_order(state, _order_state, []) do
    state
  end

  @doc """
  Removes multiple orders from the state map.
  """
  def remove_order(state, order_state, orders)
      when is_list(orders) do
    Enum.reduce(orders, state, fn order, int_state ->
      IO.inspect({order, int_state})
      remove_order(int_state, order_state, order)
    end)
  end

  @doc """
  Removes a single order from the state map.
  """
  def remove_order(state, order_state, %Order{} = order) do
    {_complete, new_state} = pop_in(state, [order_state, order.id])
    new_state
  end

  @doc """
  Fetches the node affiliated with the node_name's order.
  """
  def fetch_node(state, node_name) do
    state
    |> Map.get(:active)
    |> Map.values()
    |> Enum.filter(fn order -> order.node == node_name end)
  end

  @doc """
  Fetch all cab orders.
  """
  def fetch_order_type(orders, :cab) do
    Enum.filter(orders, fn order -> order.button_type in @cab_orders end)
  end

  @doc """
  Fetch all hall orders.
  """
  def fetch_order_type(orders, :hall) do
    Enum.filter(orders, fn order -> order.button_type in @hall_orders end)
  end

  @doc """
  Iterates over the orders with reinject_order(%Order{} = order).
  """
  def reinject_order(orders)
      when is_list(orders) do
    Enum.each(orders, fn order -> reinject_order(order) end)
  end

  @doc """
  Reinjects the provided order into OrderDistribution.
  """
  def reinject_order(%Order{} = order) do
    IO.inspect(order)
    OrderDistribution.new_order(order)
  end

  @doc """
  Iterates over the orders with move_to_standby(state, %Order{} = order).
  """
  def move_to_standby(state, orders)
      when is_list(orders) do
    Enum.reduce(orders, state, fn order, int_state ->
      move_to_standby(int_state, order)
    end)
  end

  @doc """
  Moves the given order to stand_by state in the state map by deleting the order
  in active state and adding it to the stand_by state. Returns the rebuilt state map.
  """
  def move_to_standby(state, %Order{} = order) do
    new_active =
      state
      |> Map.get(:active)
      |> Map.delete(order.id)

    new_standby =
      state
      |> Map.get(:stand_by)
      |> Map.put(order.id, order)

    IO.inspect(new_active)
    IO.inspect(new_standby)
    %{active: new_active, stand_by: new_standby}
  end

  def read_from_backup(filename) do
    case FileBackup.read(filename) do
      {:error, :enoent} ->
        %{active: %{}, stand_by: %{}}

      {:ok, backup_state} ->
        active =
          backup_state
          |> Map.get(:active)
          |> Map.values()
          |> Enum.filter(fn order -> Time.diff(Time.utc_now(), order.time) <= 120 end)
          |> Map.new(fn order -> {order.id, order} end)

        stand_by =
          backup_state
          |> Map.get(:stand_by)
          |> Map.values()
          |> Enum.filter(fn order -> Time.diff(Time.utc_now(), order.time) <= 10_000 end)
          |> Map.new(fn order -> {order.id, order} end)

        %{active: active, stand_by: stand_by}
    end
  end
end
