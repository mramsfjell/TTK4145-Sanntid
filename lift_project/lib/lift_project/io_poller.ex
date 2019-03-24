defmodule ButtonPoller.Supervisor do
  @moduledoc """
  Supervisor for the button poller.
  """
  use Supervisor

  def start_link([floors]) do
    Supervisor.start_link(__MODULE__, {:ok, floors}, name: Button.Supervisor)
  end

  @doc """
  Initializes the supervisor for the button poller.
  @spec init(:ok, floors :: integer) :: {:ok, tuple()}
  """
  def init({:ok, floors}) do
    available_order_buttons = get_all_button_types(floors)
    Enum.each(available_order_buttons, fn {floor,button_type} -> Driver.set_order_button_light(floor, button_type, :off) end)
    children =
      Enum.each(available_order_buttons, fn {floor, button_type} -> ButtonPoller.child_spec(floor, button_type)) end)
    end

    opts = [strategy: :one_for_one, name: Button.Supervisor]
    Supervisor.init(children, opts)
  end


  @doc """
  Returns all the different types of buttons on the elevator panel.
  ## Examples
      iex> ButtonPoller.Supervisor.get_all_button_types
      [:hall_up, :hall_down, :cab]
  """

  def get_all_button_types do
    [:hall_up, :hall_down, :cab]
  end

  @doc """
  Returns all possible orders of a single button type, given the number of the top floor
  Returns a list of tuples on the from {button_type, floor}
  ## Examples
      iex> ButtonPoller.Supervisor.get_all_button_types(:hall_up, 3)
      [
      %ElevatorOrder{floor: 0, type: :hall_up},
      %ElevatorOrder{floor: 1, type: :hall_up},
      %ElevatorOrder{floor: 2, type: :hall_up},
      ]
  """

  def get_buttons_of_type(button_type, top_floor) do
    floor_list = case button_type do
      :hall_up -> 0..top_floor-1
      :hall_down -> 1..top_floor
      :cab -> 0..top_floor
    end
    floor_list |> Enum.map(fn floor -> %ElevatorOrder{floor: floor, type: button_type} end)
  end

  @doc """
  Returns all possible orders on a single elevator
  Returns a list of tuples on the from {button_type, floor}
  ## Examples
      iex> ButtonPoller.Supervisor.get_all_buttons(3)
      [
      %ElevatorOrder{floor: 0, type: :hall_up},
      %ElevatorOrder{floor: 1, type: :hall_up},
      %ElevatorOrder{floor: 2, type: :hall_up},
      %ElevatorOrder{floor: 1, type: :hall_down},
      %ElevatorOrder{floor: 2, type: :hall_down},
      %ElevatorOrder{floor: 3, type: :hall_down},
      %ElevatorOrder{floor: 0, type: :cab},
      %ElevatorOrder{floor: 1, type: :cab},
      %ElevatorOrder{floor: 2, type: :cab},
      %ElevatorOrder{floor: 3, type: :cab},
      ]
  """

  def get_all_buttons(top_floor) do
    get_all_button_types() |> Enum.map(fn button_type -> get_buttons_of_type(button_type, top_floor) end) |> List.flatten
  end

end

defmodule ButtonPoller do
  @moduledoc """
  Registrates a single event when a button event is beeing triggered in a
  sequence.
  """
  use Task

  def start_link([floor, button_type]) do
    Task.start_link(__MODULE__, :poller, [floor, button_type, :released])
  end

  def child_spec(floor, button_type) do
    %{id: to_string(floor) <> to_string(button_type), start: {__MODULE__, :start_link, [button_info]}, restart: :permanent, type: :worker}
  end

  @doc """
  State transitions for the state machine, the button poller.
  Registrates if a given button is not being pushed, transitioning from
  low to high or high to low, or being held continuously.
  """

  def poller(floor, button_type, :released) do
    :timer.sleep(200)

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
    # IO.puts("Tester")
    OrderDistribution.new_order(floor, button_type)
    poller(floor, button_type, :pushed)
  end

  def poller(floor, button_type, :pushed) do
    :timer.sleep(200)
    # testvar = Driver.get_order_button_state(floor,button_type)
    # IO.inspect(testvar)
    case Driver.get_order_button_state(floor, button_type) do
      0 ->
        poller(floor, button_type, :released)

      1 ->
        # IO.puts("PUSHED")
        poller(floor, button_type, :pushed)

      {:error, :timeout} ->
        poller(floor, button_type, :released)
    end
  end
end

defmodule FloorPoller do
  @moduledoc """
  Registrates a single event when a floor event is beeing triggered in a
  sequence, eg. the floor sensor is high when a floor is reached and the lift stays
  at the floor.
  """

  use Task

  def start_link() do
    Task.start_link(__MODULE__, :poller, [:idle])
  end

  def child_spec([id]) do
    %{id: id, start: {__MODULE__, :start_link, []}, restart: :permanent, type: :worker}
  end

  @doc """
  State transitions for the state machine, the floor sensor poller.
  Registrates if a given floor sensor is high, or if the lift is currently
  between floors.
  """

  def poller(:idle) do
    :timer.sleep(200)

    case Driver.get_floor_sensor_state() do
      :between_floors ->
        poller(:between_floors)

      _other ->
        poller(:idle)
    end
  end

  def poller(:between_floors) do
    :timer.sleep(200)
    poller(Driver.get_floor_sensor_state())
  end

  def poller(floor) do
    Lift.at_floor(floor)
    Driver.set_floor_indicator(floor)
    poller(:idle)
  end
end
