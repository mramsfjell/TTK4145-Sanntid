defmodule Driver do
  @moduledoc """
  Cloned from https://github.com/TTK4145/driver-elixir.
  Both the logic for the obstruction switch and stop button, 
  and the need to specify pid, has been removed.
  """
  use GenServer
  @call_timeout 1000
  @button_map %{:hall_up => 0, :hall_down => 1, :cab => 2}
  @state_map %{:on => 1, :off => 0}
  @direction_map %{:up => 1, :down => 255, :stop => 0}

  @name :driver

  def start_link(_args \\ []) do
    start_link({127, 0, 0, 1}, 15657)
  end

  def start_link(address, port) do
    GenServer.start_link(__MODULE__, [address, port], name: @name)
  end

  def stop do
    GenServer.stop(@name)
  end

  def init([address, port]) do
    {:ok, socket} = :gen_tcp.connect(address, port, [{:active, false}])
    {:ok, socket}
  end

  # API -------------------------------------------------------------------------

  @doc """
  Set the direction of the motor of the lift, direction can be :up/:down/:stop.
  """
  def set_motor_direction(direction) do
    GenServer.cast(@name, {:set_motor_direction, direction})
  end

  @doc """
  Set the light in an order button.
  button_type can be :hall_up/:hall_down/:cab, state can be :on/:off.
  """
  def set_order_button_light(floor, button_type, state) do
    GenServer.cast(@name, {:set_order_button_light, button_type, floor, state})
  end

  @doc """
  Set the floor indicator to the last registered floor sensor.
  """
  def set_floor_indicator(floor) do
    GenServer.cast(@name, {:set_floor_indicator, floor})
  end

  @doc """
  Set the stop button light, state can be :on/:off.
  """
  def set_stop_button_light(state) do
    GenServer.cast(@name, {:set_stop_button_light, state})
  end

  @doc """
  Set the door light, state can be :on/:off.
  """
  def set_door_open_light(state) do
    GenServer.cast(@name, {:set_door_open_light, state})
  end

  @doc """
  Retrieve the state of an order button., button_type can be :hall_up/:hall_down/:cab.
  """
  def get_order_button_state(floor, button_type) do
    GenServer.call(@name, {:get_order_button_state, floor, button_type})
  end

  @doc """
  Retrieve the state of the floor sensor of the lift, return values can be :between_floors/integer.
  """
  def get_floor_sensor_state do
    GenServer.call(@name, :get_floor_sensor_state)
  end

  # Casts  ------------------------------------------------------------------------
  
  def handle_cast({:set_motor_direction, direction}, socket) do
    :gen_tcp.send(socket, [1, @direction_map[direction], 0, 0])
    {:noreply, socket}
  end

  def handle_cast({:set_order_button_light, button_type, floor, state}, socket) do
    :gen_tcp.send(socket, [2, @button_map[button_type], floor, @state_map[state]])
    {:noreply, socket}
  end

  def handle_cast({:set_floor_indicator, floor}, socket) do
    :gen_tcp.send(socket, [3, floor, 0, 0])
    {:noreply, socket}
  end

  def handle_cast({:set_door_open_light, state}, socket) do
    :gen_tcp.send(socket, [4, @state_map[state], 0, 0])
    {:noreply, socket}
  end

  # Calls  -----------------------------------------------------------------------

  def handle_call({:get_order_button_state, floor, order_type}, _from, socket) do
    :gen_tcp.send(socket, [6, @button_map[order_type], floor, 0])
    {:ok, [6, state, 0, 0]} = :gen_tcp.recv(socket, 4, @call_timeout)
    {:reply, state, socket}
  end

  def handle_call(:get_floor_sensor_state, _from, socket) do
    :gen_tcp.send(socket, [7, 0, 0, 0])

    button_state =
      case :gen_tcp.recv(socket, 4, @call_timeout) do
        {:ok, [7, 0, _, 0]} -> :between_floors
        {:ok, [7, 1, floor, 0]} -> floor
      end

    {:reply, button_state, socket}
  end
end
