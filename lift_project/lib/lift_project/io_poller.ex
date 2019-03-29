defmodule ButtonPoller do
  @moduledoc """
  Will through a state machine prevent that a continous push of a orderbutton
  won't spam the system with orders.

  Uses the following modules:
  - Driver
  - OrderDistribution
  """
  use Task

  def start_link(floor, button_type) do
    Task.start_link(__MODULE__, :poller, [floor, button_type, :released])
  end

  def child_spec(floor, button_type) do
    %{
      id: to_string(floor) <> to_string(button_type),
      start: {__MODULE__, :start_link, [floor, button_type]},
      restart: :permanent,
      type: :worker
    }
  end

  #Poller logic influenced by Jostein Løwer.
  def poller(floor, button_type, :released) do
    Process.sleep(200)

    case Driver.get_order_button_state(floor, button_type) do
      0 ->
        poller(floor, button_type, :released)

      1 ->
        poller(floor, button_type, :rising_edge)

      {:error, :timeout} ->
        poller(floor, button_type, :released)
    end
  end

  def poller(floor, button_type, :rising_edge) do
    OrderDistribution.new_order(floor, button_type)
    poller(floor, button_type, :pushed)
  end

  def poller(floor, button_type, :pushed) do
    Process.sleep(200)
    case Driver.get_order_button_state(floor, button_type) do
      0 ->
        poller(floor, button_type, :released)

      1 ->
        poller(floor, button_type, :pushed)

      {:error, :timeout} ->
        poller(floor, button_type, :released)
    end
  end
end

defmodule FloorPoller do
  @moduledoc """
  Will through a state machine prevent that a continous triggering of a floor
  sensor won't spam with :at_floor.

  Uses the following modules:
  - Driver
  - Lift
  """
  use Task

  def start_link() do
    Task.start_link(__MODULE__, :poller, [:between_floors])
  end

  def child_spec([id]) do
    %{id: id, start: {__MODULE__, :start_link, []}, restart: :permanent, type: :worker}
  end

  #Poller logic influenced by Jostein Løwer.
  def poller(:idle) do
    Process.sleep(200)
    case Driver.get_floor_sensor_state() do
      :between_floors ->
        poller(:between_floors)
      _other ->
        poller(:idle)
    end
  end

  def poller(:between_floors) do
    Process.sleep(100)
    poller(Driver.get_floor_sensor_state())
  end

  def poller(floor) do
    Lift.at_floor(floor)
    Driver.set_floor_indicator(floor)
    poller(:idle)
  end
end
