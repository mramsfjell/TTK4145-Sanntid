defmodule OrderServer do
  @moduledoc """
  This module keeps track of orders collected from OrderDistribution, in addition to
  setting hall lights and calculating the cost of a given order for the respective lift.
  During initialization, if the Lift process is not found, OrderServer tries again.
  """
  use GenServer

  @valid_dir [:up, :down]
  @up_dir [:cab, :hall_up]
  @down_dir [:cab, :hall_down]
  @name :order_server
  @direction_map %{up: 1, down: -1}
  @backup_file "order_server_backup.txt"

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  # API ---------------------------------------------------------------------------

  @doc """
  Casts that the lift is leaving a floor. The next floor is calculated, given the direction,
  and the new state is updated with the new floor and the given direction.
  """
  def update_lift_position(floor, dir) do
    GenServer.cast(@name, {:lift_leaving_floor, floor, dir})
  end

  @doc """
  Casting that an order has been completed, given a full order struct
  as defined in the Order module.
  """
  def order_complete(%Order{} = order) do
    GenServer.cast(@name, {:order_complete, order})
  end

  @doc """
  Casting that a lift is ready to receive a new order.
  """
  def lift_ready() do
    GenServer.cast(@name, {:lift_ready})
  end

  @doc """
  Calling for the cost of a lift potentially executing a order.
  """
  def evaluate_cost(order) do
    GenServer.call(@name, {:evaluate_cost, order})
  end

  @doc """
  Create a new order, and turns on the button light.
  """
  def new_order(order) do
    GenServer.call(@name, {:new_order, order})
  end

  @doc """
  Get current orders, used for debugging purposes only.
  """
  def get_orders() do
    GenServer.call(@name, {:get})
  end

  # Callbacks -------------------------------------------------------------------

  def init([]) do
    case Lift.get_position() do
      {:ok, floor, dir} ->
        {active, complete} = read_from_backup(@backup_file)

        state = %{
          active: active,
          complete: complete,
          floor: floor,
          dir: dir,
          last_order: nil
        }

        Enum.each(active, fn {_id, order} -> set_button_light(order, :on) end)
        Process.send_after(self, {:clean_outdated_orders}, 30_000)
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
    IO.inspect(order, label: "complete order")
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

  def handle_call({:get}, _from, state) do
    {:reply, {:ok, state}, %{} = state}
  end

  def handle_info({:order_complete_broadcast, order}, state) do
    # IO.inspect(order)
    new_state = remove_order(state, order)
    set_button_light(order, :off)
    WatchDog.order_complete(order)
    # FileBackup.write(state, @backup_file)
    {:noreply, %{} = new_state}
  end

  def handle_info({:clean_outdated_orders}, state) do
    new_state = delete_outdated_orders(state)
    {:noreply, %{} = new_state}
  end

  # Order data functions --------------------------------------------------------------

  @doc """
  Add the given order to the :active Map in the state of the OrderServer.

  ## Examples
    iex> state = %{active: %{}}
    iex> order = Order.new(2,:hall_up)
    iex> OrderServer.add_order(state,order)
    %{active: %{order.id => order}}
  """
  def add_order(state, order) do
    put_in(state, [:active, order.id], order)
  end

  @doc """
  Removes a list of orders that has been handled.
  """
  def remove_order(state, orders) when is_list(orders) do
    Enum.reduce(orders, state, fn order, int_state -> remove_order(int_state, order) end)
  end

  @doc """
  Removes an order by moving an order from the :active Map to the :complete Map.
  The order is a struct as defined in the Order module.

  Returns the updated state Map.

  ## Examples
    iex> order = Order.new(2,:hall_up)
    iex> state = %{active: %{}, complete: %{}}
    iex> OrderServer.add_order(state,order)
    iex> OrderServer.remove_order(state,order)
    %{active: %{}, complete: %{order.id => order}}
  """
  def remove_order(state, %Order{id: id} = order) do
    {_complete_order, new_state} = pop_in(state, [:active, order.id])
    new_state = put_in(new_state, [:complete, order.id], order)
  end

  @doc """
  Check if there exists an order with a given id in the :complete Map.

  Returns true if this is the case.

  ## Examples
    iex> order_1 = Order.new(1,:cab)
    iex> order_2 = Order.new(3,:hall_down)
    iex> state = %{complete: %{order_1.id => order_1, order_2.id => order_2}}
    iex> Order.order_in_complete?(state, order_1)
    true
  """
  def order_in_complete?(state, order) do
    Enum.any?(state.complete, fn {id, _complete_order} -> id == order.id end)
    |> IO.inspect(label: "order_in _complete?")
  end

  @doc """
  Returns a list of all orders being handled by the node corresponding to node_name,
  with the order floor matching the provided floor.
  """
  def fetch_orders(orders, node_name, floor, button, dir) do
    order_dir = button_to_dir(button, dir)

    orders
    |> Map.values()
    |> Enum.filter(fn order -> order.node == node_name end)
    |> Enum.filter(fn order -> Order.order_at_floor?(order, floor, order_dir) end)
  end

  def filter_node(orders, node_name) do
    orders
    |> Map.values()
    |> Enum.filter(fn order -> order.node == node_name end)
  end

  @doc """
  Returns a new direction given a button_type and the last direction.
  If button_type is :cab, the last direction is returned.

  ## Examples
    iex> button_to_dir(:cab, :down)
    :down
    iex> button_to_dir(:hall_up, :down)
    :up
  """
  def button_to_dir(button, dir) do
    case button do
      :hall_up -> :up
      :hall_down -> :down
      :cab -> dir
    end
  end

  # Shell functions ---------------------------------------------------------------------

  @doc """
  Assigns a new order to the lift, and updates the :last_order in the state.

  Returns the updated state Map.
  """
  def assign_new_lift_order(%{floor: floor, dir: dir} = state) do
    active_orders =
      Map.values(state.active) |> Enum.filter(fn order -> order.node == Node.self() end)

    case OrderServer.Cost.next_order(active_orders, floor, dir) do
      nil ->
        Map.put(state, :last_order, nil)

      order ->
        Lift.new_order(order)
        Map.put(state, :last_order, order)
    end
  end

  @doc """
  Send a given order and an :order_complete_broadcast message to the :order_server
  on the remote_node.

  Returns :ok if the message is sent.
  """
  def send_complete_order(remote_node, order) do
    Process.send({:order_server, remote_node}, {:order_complete_broadcast, order}, [:noconnect])
  end

  @doc """
  Broadcasts a list of completed orders.
  """
  def broadcast_complete_order(orders) when is_list(orders) do
    Enum.each(orders, fn order -> broadcast_complete_order(order) end)
  end

  @doc """
  Broadcasts an order to all nodes in the cluster, when the order is a
  struct as defined in the Order module.
  """
  def broadcast_complete_order(%Order{} = order) do
    Enum.each(Node.list(), fn remote_node ->
      send_complete_order(remote_node, order)
    end)
  end

  @doc """
  Set cab light for a given order struct, if the executing node of the order
  matches Node.self(). light_state can be :on/:off.

  Returns :ok
  """
  def set_button_light(%Order{button_type: :cab} = order, light_state) do
    if order.node == Node.self() do
      Driver.set_order_button_light(order.floor, order.button_type, light_state)
    end

    :ok
  end

  @doc """
  Set hall light for a given order struct. light_state can be :on/:off.
  """
  def set_button_light(%Order{button_type: button, floor: floor}, light_state)
      when button == :hall_up or button == :hall_down do
    Driver.set_order_button_light(floor, button, light_state)
  end

  def read_from_backup(filename) do
    case FileBackup.read(filename) do
      {:error, :enoent} ->
        {%{}, %{}}

      {:ok, backup_state} ->
        active =
          backup_state
          |> Map.get(:active)
          |> Map.values()
          |> Enum.filter(fn order -> Time.diff(Time.utc_now(), order.time) <= 180 end)
          |> Map.new(fn order -> {order.id, order} end)

        complete =
          backup_state
          |> Map.get(:complete)
          |> Map.values()
          |> Enum.filter(fn order -> Time.diff(Time.utc_now(), order.time) <= 10 * 60 end)
          |> Map.new(fn order -> {order.id, order} end)

        {active, complete}
    end
  end

  def delete_outdated_orders(state) do
    new_state =
      state
      |> Map.get(:complete)
      |> Map.values()
      |> Enum.filter(fn order ->
        Time.diff(Time.utc_now(), order.time) |> IO.inspect() <= 10 * 60
      end)
      |> Map.new(fn order -> {order.id, order} end)

    Process.send_after(self, {:clean_outdated_orders}, 30_000)
    Map.put(state, :complete, new_state)
  end
end
