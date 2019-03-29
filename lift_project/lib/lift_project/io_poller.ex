defmodule ButtonPoller.Supervisor do
  use Supervisor

  def start_link([floors]) do
    Supervisor.start_link(__MODULE__, {:ok, floors}, name: Button.Supervisor)
  end

  @doc """
  Initializes the supervisor for the button poller. Turns off all button lights.
  @spec init(:ok, floors :: integer) :: {:ok, tuple()}
  """
  def init({:ok, floors}) do
    available_order_buttons = get_all_buttons(floors)

    Enum.each(available_order_buttons, fn button ->
      Driver.set_order_button_light(button.floor, button.type, :off)
      end)

    children =
      Enum.map(available_order_buttons, fn button ->
        ButtonPoller.child_spec(button.floor, button.type)
      end)

    opts = [strategy: :one_for_one, name: Button.Supervisor]
    Supervisor.init(children, opts)
  end

  #Credited: Jostein Løwer. https://github.com/jostlowe/kokeplata/tree/master/lib (24.03.19)
  def get_all_button_types do
    [:hall_up, :hall_down, :cab]
  end

  #Credited: Jostein Løwer. https://github.com/jostlowe/kokeplata/tree/master/lib (24.03.19)
  def get_buttons_of_type(button_type, top_floor) do
    floor_list =
      case button_type do
        :hall_up -> 0..(top_floor - 1)
        :hall_down -> 1..top_floor
        :cab -> 0..top_floor
      end
    floor_list |> Enum.map(fn floor -> %{floor: floor, type: button_type} end)
  end

  #Credited: Jostein Løwer. https://github.com/jostlowe/kokeplata/tree/master/lib (24.03.19)
  def get_all_buttons(floors) do
    top_floor = floors - 1

    get_all_button_types()
    |> Enum.map(fn button_type -> get_buttons_of_type(button_type, top_floor) end)
    |> List.flatten()
  end
end

defmodule ButtonPoller do
  @moduledoc """
    Will through a state machine prevent that a continous push of a orderbutton
    won't spam the system with orders.
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
