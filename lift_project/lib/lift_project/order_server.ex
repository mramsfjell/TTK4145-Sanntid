defmodule OrderServer do
  @moduledoc """
  This module keeps track of orders collected from OrderDistribution in addition to setting hall lights and path logic.
  """
  use GenServer

  @valid_dir [:up, :down]
  @up_dir [:cab, :hall_up]
  @down_dir [:cab, :hall_down]
  @name :order_server
  @direction_map %{up: 1, down: -1}

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  # API -----------------------------------------------------------------------

  # Casts that the lift is leaving a floor
  def leaving_floor(floor, dir) do
    GenServer.cast(@name, {:lift_leaving_floor, floor, dir})
  end

  @doc """
  Casting that an order has been completed given a full order struct
  """
  def order_complete(%Order{} = order) do
    GenServer.cast(@name, {:order_complete, order})
  end

  @doc """
  Casting that a lift is ready for a new order
  """
  def lift_ready() do
    GenServer.cast(@name, {:lift_ready})
  end

  @doc """
  Calling for the cost of a lift potentially executing a order
  """

  def evaluate_cost(order) do
    GenServer.call(@name, {:evaluate_cost, order})
  end

  @doc """
  Create new order
  """
  def new_order(order) do
    GenServer.call(@name, {:new_order, order})
  end

  @doc """
  Get current orders, for debugging purposes
  """
  def get_orders() do
    GenServer.call(@name, {:get})
  end

  # Callbacks --------------------------------------------------

  def init([]) do
    case Lift.get_state() do
      {:ok, floor, dir} ->
        state = %{
          active: %{},
          complete: %{},
          floor: floor,
          dir: dir,
          last_order: nil
        }

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

    {:noreply, %{} = new_state}
  end

  def handle_cast({:lift_ready}, state) do
    new_state = assign_new_lift_order(state)
    {:noreply, %{} = new_state}
  end

  def handle_call({:evaluate_cost, order}, _from, state) do
    reply =
      if order_in_complete?(state, order) do
        {:completed, 0}
      else
        active_orders = Map.values(state.active)
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
    {:noreply, %{} = new_state}
  end

  # Order data functions--------------------------------------------------------

  def add_order(state, order) do
    put_in(state, [:active, order.id], order)
  end

  def remove_order(state, orders) when is_list(orders) do
    Enum.reduce(orders, state, fn order, int_state -> remove_order(int_state, order) end)
  end

  def remove_order(state, %Order{time: time} = order) do
    {_complete_order, new_state} = pop_in(state, [:active, time])
    new_state = put_in(new_state, [:complete, order.id], order)
  end

  def order_in_complete?(state, order) do
    Enum.any?(state.complete, fn {id, _complete_order} -> id == order.id end) |> IO.inspect()
  end

  def fetch_orders(orders, node_name, floor, button, dir) do
    order_dir = button_to_dir(button, dir)

    orders
    |> Map.values()
    |> Enum.filter(fn order -> order.node == node_name end)
    |> Enum.filter(fn order -> Order.order_at_floor?(order, floor, order_dir) end)
  end

  def button_to_dir(button, dir) do
    case button do
      :hall_up -> :up
      :hall_down -> :down
      :cab -> dir
    end
  end

  # Shell functions

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

  def send_complete_order(remote_node, order) do
    Process.send({:order_server, remote_node}, {:order_complete_broadcast, order}, [:noconnect])
  end

  def broadcast_complete_order(orders) when is_list(orders) do
    Enum.each(orders, fn order -> broadcast_complete_order(order) end)
  end

  def broadcast_complete_order(%Order{} = order) do
    Enum.each(Node.list(), fn remote_node ->
      send_complete_order(remote_node, order)
    end)
  end

  def set_button_light(%Order{button_type: :cab} = order, light_state) do
    if order.node == Node.self() do
      Driver.set_order_button_light(order.floor, order.button_type, light_state)
    end

    :ok
  end

  def set_button_light(%Order{button_type: button, floor: floor}, light_state)
      when button == :hall_up or button == :hall_down do
    Driver.set_order_button_light(floor, button, light_state)
  end
end
