defmodule Order do
  @moduledoc """
  Defining the data structure for, and creation of a order. The timestamp is used as an order ID.
  """
  @valid_order [:hall_down, :cab, :hall_up]
  @enforce_keys [:floor, :button_type]
  defstruct [:floor, :button_type, :time, node: nil, watch_dog: nil]

  def new(floor, button_type)
      when is_integer(floor) and button_type in @valid_order do
    %Order{
      floor: floor,
      button_type: button_type,
      time: Time.utc_now(),
      node: Node.self()
    }
  end
end

defmodule OrderServer do
  @moduledoc """
  This module keeps track of orders collected from OrderDistribution in addition to setting hall lights and path logic.
  """

  use GenServer

  @valid_dir [:up, :down]
  @up_dir [:cab, :hall_up]
  @down_dir [:cab, :hall_down]
  @name :order_server

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: @name)
  end


  # API -----------------------------------------------------------------------
  
  # Casts that the lift is leaving a floor
  def leaving_floor(floor, dir) do
    GenServer.cast(@name, {:lift_update, floor, dir})
  end

  # Casting that an order has been completed given floor and direction
  def order_complete(floor, dir) when is_integer(floor) and dir in @valid_dir do
    GenServer.cast(@name, {:order_complete, floor, dir})
  end

  # Casting that an order has been completed given a full order struct
  def order_complete(%Order{} = order) do
    GenServer.cast(@name, {:order_complete, order})
  end

  # Casting that a lift is ready for a new order
  def lift_ready() do
    GenServer.cast(@name, {:lift_ready})
  end

  # Calling for the cost of a lift potentially executing a order
  def evaluate_cost(order) do
    GenServer.call(@name, {:evaluate_cost, order})
  end

  # Create new order
  def new_order(order) do
    GenServer.call(@name, {:new_order, order})
  end

  # Get current orders
  def get_orders() do
    GenServer.call(@name, {:get})
  end


  # Callbacks --------------------------------------------------
  
  def init([]) do
    case Lift.get_state() do
      {floor, dir} ->
        state = %{
          active: %{},
          complete: %{},
          floor: floor,
          dir: dir,
          last_order: nil
        }

        {:ok, state}

      other ->
        IO.inspect(other)
        init([])
    end
  end

  def handle_cast({:lift_update, floor, dir}, state) do
    next_floor = floor + dir_to_int(dir)

    new_state =
      state
      |> Map.put(:floor, next_floor)
      |> Map.put(:dir, dir)

    {:noreply, %{} = new_state}
  end

  def handle_cast({:order_complete, floor, dir}, state) do
    orders = fetch_orders(state.active, Node.self(), floor, dir)

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
    active_orders = Map.values(state.active)
    cost = OrderServer.Cost.calculate_cost(active_orders, state.floor, state.dir, order)
    {:reply, cost, state}
  end

  def handle_call({:new_order, order}, _from, state) do
    new_state =
      state
      |> add_order(order)
      |> assign_new_lift_order

    # Only set cab-light in own cab
    set_button_light(order, :on)
    {:reply, order, %{} = new_state}
  end

  def handle_call({:get}, _from, state) do
    {:reply, {:ok, state}, %{} = state}
  end

  def handle_info({:order_complete, order}, state) do
    # IO.inspect(order)
    new_state = remove_order(state, order)
    set_button_light(order, :off)
    WatchDog.order_complete(order)
    {:noreply, %{} = new_state}
  end


  # Helper functions ----------------------------------------------------------

  def add_order(state, order) do
    put_in(state, [:active, order.time], order)
  end

  def remove_order(state, orders) when is_list(orders) do
    Enum.reduce(orders, state, fn order, int_state -> remove_order(int_state, order) end)
  end

  def remove_order(state, %Order{time: time} = order) do
    {_complete_order, new_state} = pop_in(state, [:active, time])
    new_state = put_in(new_state, [:complete, order.time], order)
  end

  def order_at_floor?(order, floor, :up) do
    order.floor == floor and order.button_type in @up_dir
  end

  def order_at_floor?(%Order{} = order, floor, :down) do
    order.floor == floor and order.button_type in @down_dir
  end

  def fetch_orders(orders, node_name, floor, dir) do
    orders
    |> Map.values()
    |> Enum.filter(fn order -> order.node == node_name end)
    |> Enum.filter(fn order -> order_at_floor?(order, floor, dir) end)
  end

  def assign_new_lift_order(%{floor: floor, dir: dir} = state) do
    active_orders = Map.values(state.active)

    case OrderServer.Cost.next_order(active_orders, floor, dir) do
      nil ->
        Map.put(state, :last_order, nil)

      order ->
        next_order = order_to_dir(state, order)
        Lift.new_order(next_order)
        Map.put(state, :last_order, next_order)
    end
  end

  def send_complete_order(remote_node, order) do
    # NOTE something to check that the message were sent?
    Process.send({:order_server, remote_node}, {:order_complete, order}, [:noconnect])
  end

  def broadcast_complete_order(orders) when is_list(orders) do
    Enum.each(orders, fn order -> broadcast_complete_order(order) end)
  end

  def broadcast_complete_order(%Order{} = order) do
    Enum.each(Node.list(), fn remote_node ->
      send_complete_order(remote_node, order)
    end)
  end

  def set_button_light(%{button_type: :cab} = order, ligth_state) do
    if order.node == Node.self() do
      Driver.set_order_button_light(order.floor, order.button_type, ligth_state)
    end

    :ok
  end

  def set_button_light(order, ligth_state) do
    Driver.set_order_button_light(order.floor, order.button_type, ligth_state)
  end

  def order_to_dir(%{dir: last_dir}, %Order{button_type: button, floor: floor}) do
    dir =
      case button do
        :hall_up -> :up
        :hall_down -> :down
        :cab -> last_dir
      end

    {floor, dir}
  end

  def dir_to_int(:up), do: 1
  def dir_to_int(:down), do: -1
end
