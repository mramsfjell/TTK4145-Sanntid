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
    children =
      Enum.flat_map(0..(floors - 1), fn floor ->
        cond do
          floor == 0 ->
            [
              ButtonPoller.child_spec(["u" <> to_string(floor), floor, :hall_up]),
              ButtonPoller.child_spec(["c" <> to_string(floor), floor, :cab])
            ]

          floor == floors - 1 ->
            [
              ButtonPoller.child_spec(["d" <> to_string(floor), floor, :hall_down]),
              ButtonPoller.child_spec(["c" <> to_string(floor), floor, :cab])
            ]

          0 < floor and floor < floors - 1 ->
            [
              ButtonPoller.child_spec(["u" <> to_string(floor), floor, :hall_up]),
              ButtonPoller.child_spec(["d" <> to_string(floor), floor, :hall_down]),
              ButtonPoller.child_spec(["c" <> to_string(floor), floor, :cab])
            ]
        end
      end)

    opts = [strategy: :one_for_one, name: Button.Supervisor]
    Supervisor.init(children, opts)
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

  def child_spec([id | button_info]) do
    %{id: id, start: {__MODULE__, :start_link, [button_info]}, restart: :permanent, type: :worker}
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
