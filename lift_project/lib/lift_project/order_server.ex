defmodule OrderServer do
  @moduledoc """
  This module keeps track of orders collected from OrderDistribution, in addition to
  setting hall lights and calculating the cost of a given order for the respective lift.
  Initialization is not completed uuntil the lift is ready.

  Uses the following modules:
  - Lift
  - OrderDistribution
  - FileBackup
  - WatchDog
  - Lift
  - Driver
  """
  use GenServer

  @name :order_server
  @direction_map %{up: 1, down: -1}
  @backup_file "order_server_backup.txt"

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  # API ------------------------------------------------------------------------

  @doc """
  Send message that the lift is leaving a floor. The next floor is calculated, given the direction,
  and the new state is updated with the new floor and the given direction.
  """

  def update_lift_position(floor, dir) do
    GenServer.cast(@name, {:lift_leaving_floor, floor, dir})
  end

  @doc """
  Send message that an order has been completed, given a full order struct
  as defined in the Order module.
  """
  def order_complete(%Order{} = order) do
    GenServer.cast(@name, {:order_complete, order})
  end

  @doc """
  Send message that a lift is ready to receive a new order.
  """
  def lift_ready() do
    GenServer.cast(@name, {:lift_ready})
  end

  @doc """
  Synchronous call for the cost of a lift potentially executing a order.
  """
  def evaluate_cost(order) do
    GenServer.call(@name, {:evaluate_cost, order})
  end

  @doc """
  Synchronous call assigning a new order. Turns on the button light and returns the order as an accnowledgement.
  """
  def new_order(order) do
    GenServer.call(@name, {:new_order, order})
  end

  # Callbacks ------------------------------------------------------------------

  def init([]) do
    case Lift.get_position() do
      {:ok, floor, dir} ->
        {active, complete} = read_from_backup(@backup_file)

        state = %{
          active: %{},
          complete: complete,
          floor: floor,
          dir: dir,
          last_order: nil
        }

        Enum.each(active, fn {_id, order} -> OrderDistribution.new_order(order) end)
        FileBackup.write(state, @backup_file)
        Process.send_after(self(), {:clean_outdated_orders}, 30_000)
        {:ok, state}

      _other ->
        Process.sleep(100)
        init([])
    end
  end

  def handle_cast({:lift_leaving_floor, floor, dir}, state) do
    next_floor = floor + @direction_map[dir]

    new_state =
      state
      |> Map.put(:floor, next_floor)
      |> Map.put(:dir, dir)

    {:noreply, %{} = new_state}
  end

  def handle_cast({:order_complete, order}, state) do
    orders = fetch_orders(state.active, Node.self(), order.floor, order.button_type, state.dir)

    new_state =
      state
      |> Map.put(:last_order, nil)
      |> remove_order(orders)

    Enum.each(orders, fn order ->
      WatchDog.order_complete(order)
      set_button_light(order, :off)
    end)

    broadcast_complete_order(orders)
    assign_new_lift_order(new_state)
    FileBackup.write(new_state, @backup_file)
    {:noreply, %{} = new_state}
  end

  def handle_cast({:lift_ready}, state) do
    new_state = assign_new_lift_order(state)
    FileBackup.write(new_state, @backup_file)
    {:noreply, %{} = new_state}
  end

  def handle_call({:evaluate_cost, order}, _from, state) do
    reply =
      if order_in_complete?(state, order) do
        {:completed, 0}
      else
        active_orders =
          state
          |> Map.get(:active)
          |> filter_node(Node.self())

        cost = OrderServer.Cost.calculate_cost(active_orders, state.floor, state.dir, order)
        {:ok, cost}
      end

    {:reply, reply, state}
  end

  def handle_call({:new_order, order}, _from, state) do
    new_state =
      state
      |> add_order(order)
      |> assign_new_lift_order

    set_button_light(order, :on)
    FileBackup.write(new_state, @backup_file)
    {:reply, order, %{} = new_state}
  end

  def handle_info({:order_complete_broadcast, order}, state) do
    new_state = remove_order(state, order)
    set_button_light(order, :off)
    WatchDog.order_complete(order)
    FileBackup.write(new_state, @backup_file)
    {:noreply, %{} = new_state}
  end

  def handle_info({:clean_outdated_orders}, state) do
    {_orders, new_state} = pop_outdated_orders(state, :complete, 600)
    {orders, new_state} = pop_outdated_orders(new_state, :active, 120)
    Enum.each(orders, fn order -> OrderDistribution.new_order(order) end)
    Process.send_after(self(), {:clean_outdated_orders}, 30_000)
    {:noreply, %{} = new_state}
  end

  # Order data functions -------------------------------------------------------

  defp add_order(state, order) do
    put_in(state, [:active, order.id], order)
  end

  defp remove_order(state, orders) when is_list(orders) do
    Enum.reduce(orders, state, fn order, int_state -> remove_order(int_state, order) end)
  end

  defp remove_order(state, %Order{} = order) do
    {_complete_order, new_state} = pop_in(state, [:active, order.id])
    put_in(new_state, [:complete, order.id], order)
  end

  defp order_in_complete?(state, order) do
    Enum.any?(state.complete, fn {id, _complete_order} -> id == order.id end)
  end

  defp fetch_orders(orders, node_name, floor, button, dir) do
    order_dir = button_to_dir(button, dir)

    orders
    |> Map.values()
    |> Enum.filter(fn order -> order.node == node_name end)
    |> Enum.filter(fn order -> Order.order_at_floor?(order, floor, order_dir) end)
  end

  defp filter_node(orders, node_name) do
    orders
    |> Map.values()
    |> Enum.filter(fn order -> order.node == node_name end)
  end

  defp button_to_dir(button, dir) do
    case button do
      :hall_up -> :up
      :hall_down -> :down
      :cab -> dir
    end
  end

  defp read_from_backup(filename) do
    case FileBackup.read(filename) do
      {:error, _reason} ->
        {%{}, %{}}

      {:ok, backup_state} ->
        active = filter_backup(backup_state, :active, 180)
        complete = filter_backup(backup_state, :complete, 600)
        {active, complete}
    end
  end

  defp filter_backup(backup_state, order_state, time_limit) do
    backup_state
    |> Map.get(order_state)
    |> Map.values()
    |> Enum.filter(fn order -> abs(Time.diff(Time.utc_now(), order.time)) <= time_limit end)
    |> Map.new(fn order -> {order.id, order} end)
  end

  defp pop_outdated_orders(state, order_type, time) do
    outdated_orders =
      state
      |> Map.get(order_type)
      |> Map.values()
      |> Enum.filter(fn order -> abs(Time.diff(Time.utc_now(), order.time)) >= time end)

    valid_orders =
      state
      |> Map.get(order_type)
      |> Map.values()
      |> Enum.filter(fn order -> abs(Time.diff(Time.utc_now(), order.time)) < time end)
      |> Map.new(fn order -> {order.id, order} end)

    new_state = Map.put(state, order_type, valid_orders)
    {outdated_orders, new_state}
  end

  # Helper functions ------------------------------------------------------------

  defp assign_new_lift_order(%{floor: floor, dir: dir} = state) do
    active_orders =
      state
      |> Map.get(:active)
      |> Map.values()
      |> Enum.filter(fn order -> order.node == Node.self() end)

    case OrderServer.Cost.closest_order(active_orders, floor, dir) do
      nil ->
        Map.put(state, :last_order, nil)

      order ->
        Lift.new_order(order)
        Map.put(state, :last_order, order)
    end
  end

  defp send_complete_order(remote_node, order) do
    Process.send({:order_server, remote_node}, {:order_complete_broadcast, order}, [:noconnect])
  end

  defp broadcast_complete_order(orders) when is_list(orders) do
    Enum.each(orders, fn order -> broadcast_complete_order(order) end)
  end

  defp broadcast_complete_order(%Order{} = order) do
    Enum.each(Node.list(), fn remote_node ->
      send_complete_order(remote_node, order)
    end)
  end

  defp set_button_light(%Order{button_type: :cab} = order, light_state) do
    if order.node == Node.self() do
      Driver.set_order_button_light(order.floor, order.button_type, light_state)
    end

    :ok
  end

  defp set_button_light(%Order{button_type: button, floor: floor}, light_state)
       when button == :hall_up or button == :hall_down do
    Driver.set_order_button_light(floor, button, light_state)
  end
end
