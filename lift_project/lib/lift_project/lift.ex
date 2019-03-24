defmodule Lift do
  @moduledoc """
  Statemachine for controlling the lift given a lift order. Keeps track of one order at a time.
  """
  use GenServer

  @name :Lift_FSM
  @door_timer 2_000
  @enforce_keys [:floor, :dir, :order, :state]
  defstruct [:floor, :dir, :order, :state]

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, name: @name)
  end

  # API ------------------------------------------------------

  @doc """
  Message the state machine that the lift has reached a floor.
  """
  def at_floor(floor) do
    GenServer.cast(@name, {:at_floor, floor})
  end

  @doc """
  Assign new order to the lift.
  """
  def new_order(%Order{} = order) do
    GenServer.cast(@name, {:new_order, order})
  end

  @doc """
  Get the placement of the lift.
  """
  def get_state() do
    GenServer.call(@name, :get_state)
  end

  # Callbacks --------------------------------------------
  def init([]) do
    Driver.set_door_open_light(:off)
    data =
      case Driver.get_floor_sensor_state() do
        :between_floors ->
          Driver.set_motor_direction(:up)

          %Lift{
            state: :init,
            order: nil,
            floor: nil,
            dir: :up
          }

        floor ->
          %Lift{
            state: :idle,
            order: nil,
            floor: floor,
            dir: :up
          }
      end

    {:ok, data}
  end

  def handle_cast({:at_floor, floor}, data) do
    new_data =
      case data.state do
        :mooving -> at_floor_event(data, floor)
        :init -> complete_init(data, floor)
        # FIXME this can be removed when io is working
        _other_state -> data
      end

    {:noreply, %Lift{} = new_data}
  end

  def handle_cast({:new_order, order}, data) do
    new_data = new_order_event(data, order)
    {:noreply, %Lift{} = new_data}
  end

  def handle_call(:get_state, _from, %Lift{state: :init} = data) do
    {:reply, {:error, :not_ready}, data}
  end

  def handle_call(:get_state, _from, data) do
    {:reply, {:ok, data.floor, data.dir}, data}
  end

  def handle_info(:close_door, %Lift{state: :door_open} = data) do
    new_data = door_close_event(data)
    {:noreply, %Lift{} = new_data}
  end

  # State transitions ------------------------------------------------

  defp door_open_transition(%Lift{} = data) do
    Driver.set_motor_direction(:stop)
    Driver.set_door_open_light(:on)
    Process.send_after(self(), :close_door, @door_timer)
    IO.puts("Door open at floor #{data.floor}")
    Map.put(data, :state, :door_open)
  end

  defp mooving_transition(%Lift{dir: dir} = data) do
    Driver.set_door_open_light(:off)
    new_state = Map.put(data, :state, :mooving)
    OrderServer.leaving_floor(data.floor, data.dir)
    IO.puts("Mooving #{dir}")
    Driver.set_motor_direction(dir)
    new_state
  end

  defp idle_transition(%Lift{} = data) do
    Driver.set_motor_direction(:stop)
    Driver.set_door_open_light(:off)
    IO.puts("Ideling at floor #{data.floor}")
    Map.put(data, :state, :idle)
  end

  defp complete_init(data, floor) do
    Driver.set_motor_direction(:stop)
    # OrderServer.at_floor(floor,data.dir)
    OrderServer.lift_ready()

    data
    |> Map.put(:floor, floor)
    |> Map.put(:state, :idle)
  end

  # Events ---------------------------------------------------------------

  defp door_close_event(%Lift{order: order, floor: floor, dir: dir} = data) do
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

  defp new_order_event(%Lift{} = data, %Order{} = order) do
    add_order(data, order)
  end

  defp at_floor_event(%Lift{floor: floor, order: order} = data) do
    IO.puts("at floor#{floor}")

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

  # Helper functions ---------------------------------------------
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
end
