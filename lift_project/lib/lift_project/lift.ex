defmodule Lift do
  @moduledoc """
  Statemachine for controlling the lift given a lift order.
  Keeps track of one order at a time, and drives to complete that specific order.

  A timer is implemented in order to check if the lift cab reaches two different floor
  sensors within a reasonable amount of time. If not, the direction of the cab is set once
  again and the cab continues to drive in the same direction.

  Each transition will happen on entry to the respective state.

  Each event triggers a state change from one state to another.
  """
  use GenServer

  @name :Lift_FSM
  @door_timer 2_000
  @mooving_timer 3_000
  @enforce_keys [:state, :order, :floor, :dir, :timer]

  defstruct [:state, :order, :floor, :dir, :timer]

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, name: @name)
  end

  # API ------------------------------------------------------------------------

  @doc """
  Message the state machine that the lift has reached a floor.
  """
  def at_floor(floor) when is_integer(floor) do
    GenServer.cast(@name, {:at_floor, floor})
  end

  @doc """
  Assign a new order to the lift. If 'Lift' is in :init state,
  a message on the form {:error, :not_ready} is sent.
  """
  def new_order(%Order{} = order) do
    GenServer.cast(@name, {:new_order, order})
  end

  @doc """
  Get the possition, ie  next floor and current direction of the lift. returns
  error if the state machine is not initialized

  ## Examples
    iex> %Lift{state: :init, order: nil, floor: 0, dir: :up}
    iex> Lift.get_position()
    {:error, :not_ready}

    iex> %Lift{state: :idle, order: nil, floor: 1, dir: :up}
    iex> Lift.get_position()
    {:ok, 1, :up}
  """
  def get_position() do
    GenServer.call(@name, :get_position)
  end

  # Callbacks ----------------------------------------------------------------------

  def init([]) do
    Driver.set_door_open_light(:off)
    Driver.set_motor_direction(:up)

    data = %Lift{
      state: :init,
      order: nil,
      floor: nil,
      dir: :up,
      timer: make_ref()
    }

    {:ok, data}
  end

  def terminate(_reason, _state) do
    Driver.set_motor_direction(:stop)
  end

  def handle_cast({:at_floor, floor}, %Lift{state: :init} = data) do
    IO.inspect(data, label: "init at floor")
    new_data = complete_init(data, floor)
    {:noreply, %Lift{} = new_data}
  end

  def handle_cast({:at_floor, floor}, %Lift{state: _state} = data) do
    IO.inspect(data, label: "at floor")
    new_data = at_floor_event(data, floor)
    {:noreply, %Lift{} = new_data}
  end

  def handle_cast({:new_order, _order}, %Lift{state: :init} = data) do
    {:reply, {:error, :not_ready}, data}
  end

  def handle_cast({:new_order, order}, data) do
    new_data = new_order_event(data, order)
    {:noreply, %Lift{} = new_data}
  end

  def handle_call(:get_position, _from, %Lift{state: :init} = data) do
    {:reply, {:error, :not_ready}, data}
  end

  def handle_call(:get_position, _from, data) do
    {:reply, {:ok, data.floor, data.dir}, data}
  end

  def handle_info(:close_door, %Lift{state: :door_open} = data) do
    new_data = door_close_event(data)
    {:noreply, %Lift{} = new_data}
  end

  def handle_info(:mooving_timer, %Lift{dir: dir, state: :mooving} = data) do
    Driver.set_motor_direction(dir)
    new_data = start_timer(data)
    IO.puts("Timer ran out")
    pid = Process.whereis(:order_server)
    Process.exit(pid, :kill)
    Process.exit(self, :normal)

    {:noreply, new_data}
  end

  # State transitions -------------------------------------------------------------

  defp door_open_transition(%Lift{} = data) do
    Driver.set_motor_direction(:stop)
    Driver.set_door_open_light(:on)
    Process.send_after(self(), :close_door, @door_timer)
    IO.puts("Door open at floor #{data.floor}")
    Map.put(data, :state, :door_open)
  end

  defp mooving_transition(%Lift{dir: dir} = data) do
    Driver.set_door_open_light(:off)

    new_data =
      Map.put(data, :state, :mooving)
      |> start_timer

    OrderServer.update_lift_position(data.floor, data.dir)
    IO.puts("Mooving #{dir}")
    Driver.set_motor_direction(dir)
    new_data
  end

  defp idle_transition(%Lift{} = data) do
    Driver.set_motor_direction(:stop)
    Driver.set_door_open_light(:off)
    IO.puts("Ideling at floor #{data.floor}")
    Map.put(data, :state, :idle)
  end

  defp complete_init(data, floor) do
    Driver.set_motor_direction(:stop)
    OrderServer.lift_ready()
    new_data = Map.put(data, :floor, floor)
    NetworkInitialization.boot_node("n", 10_000)
    idle_transition(new_data)
  end

  # Events ----------------------------------------------------------------------------

  defp door_close_event(%Lift{order: order, dir: dir} = data) do
    Driver.set_door_open_light(:off)
    OrderServer.order_complete(order)
    data = Map.put(data, :order, nil)
    idle_transition(data)
  end

  defp new_order_event(%Lift{state: :idle} = data, %Order{} = order) do
    if Order.order_at_floor?(order, data.floor) do
      data
      |> add_order(order)
      |> door_open_transition
    else
      data
      |> add_order(order)
      |> update_direction()
      |> at_floor_event()
    end
  end

  defp new_order_event(
         %Lift{floor: current_floor, dir: :up} = data,
         %Order{floor: target_floor} = order
       )
       when current_floor <= target_floor do
    add_order(data, order)
  end

  defp new_order_event(
         %Lift{floor: current_floor, dir: :down} = data,
         %Order{floor: target_floor} = order
       )
       when current_floor >= target_floor do
    add_order(data, order)
  end

  defp at_floor_event(%Lift{floor: floor, order: order, timer: timer} = data) do
    IO.puts("at floor#{floor}")
    Process.cancel_timer(timer)

    case Order.order_at_floor?(order, floor) do
      true -> door_open_transition(data)
      false -> mooving_transition(data)
    end
  end

  defp at_floor_event(data, floor) do
    data
    |> Map.put(:floor, floor)
    |> at_floor_event()
  end

  # Helper functions ------------------------------------------------------------------

  defp add_order(%Lift{} = data, order) do
    Map.put(data, :order, order)
  end

  defp update_direction(%Lift{order: order, floor: floor} = data) do
    if floor < order.floor do
      Map.put(data, :dir, :up)
    else
      Map.put(data, :dir, :down)
    end
  end

  defp start_timer(%Lift{timer: timer} = data) do
    Process.cancel_timer(timer)
    timer = Process.send_after(self(), :mooving_timer, @mooving_timer)
    new_data = Map.put(data, :timer, timer)
  end
end
