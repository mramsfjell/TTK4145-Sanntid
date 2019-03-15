# Tell lift that lift is at_floor
# Set floor indicators and cab lights
# Set hall lights from OrderServer
# Poll button_push

defmodule PollerServer do
  @moduledoc """

  """

  use Task

  def start_link(button_info) do
    Task.start_link(__MODULE__, :button_poll, [button_info])
  end

  def child_spec([id|button_info]) do
    %{id: id,
      start: {__MODULE__,:start_link,[button_info]},
      restart: :permanent,
      type: :worker
    }
  end

  #Callbacks
  def handle_cast {:new_order, floor,button_type}, [] do
    OrderDistribution.new_order(floor,button_type)
    {:noreply, []}
  end

  def handle_cast {:at_floor, floor}, [] do
    Lift.at_floor(floor)
    {:noreply, []}
  end
end



defmodule ButtonPoller.Supervisor do
  @moduledoc """
  A module for registrating a single event when a buttonevent is beeing triggered in a
  sequence, eg. a button is pressed and held for some seconds.

  """
  use Supervisor

  def start_link (floors) do
    Supervisor.start_link(__MODULE__,{:ok,floors},[name: Button.Supervisor])
  end

 #
  def init({:ok,[floors]}) do
    children = Enum.flat_map(0..(floors-1), fn floor ->
      cond do
        floor == 0 ->
            [IO.Button.child_spec(["u"<>to_string(floor),:hall_up,floor]),
             IO.Button.child_spec(["c"<>to_string(floor),:cab,floor])]
        floor == (floors-1) ->
            [IO.Button.child_spec(["d"<>to_string(floor),:hall_down,floor]),
             IO.Button.child_spec(["c"<>to_string(floor),:cab,floor])]
        (0 < floor) and (floor < (floors-1)) ->
            [IO.Button.child_spec(["u"<>to_string(floor),:hall_up,floor]),
             IO.Button.child_spec(["d"<>to_string(floor),:hall_down,floor]),
             IO.Button.child_spec(["c"<>to_string(floor),:cab,floor])]
      end
    end)

    opts = [strategy: :one_for_one, name: Button.Supervisor]
    Supervisor.init(children, opts)
  end
end

defmodule ButtonPoller do
  @moduledoc """

  """
  use Task

  def start_link([floor,button_type]) do
    Task.start_link(__MODULE__, :button_poll,[floor, button_type, :off])
  end

  def child_spec([id|button_info]) do
    %{id: id,
      start: {__MODULE__,:start_link,[button_info]},
      restart: :permanent,
      type: :worker
    }
  end


  #State transitions
  def poller(floor,button_type,:released) do
    :timer.sleep(200)
    case Driver.get_order_button_state(floor,button_type) do
      0 ->
        poller(floor,button_type,:released)
      1->
        poller(floor,button_type,:rising_edge)
    end
  end

  def poller(floor,button_type,:rising_edge) do
    PollerServer.new_order(floor, button_type)
    poller(floor,button_type,:pushed)
  end

  def poller(floor,button_type,:pushed) do
    :timer.sleep(200)
    case Driver.get_order_button_state(floor,button_type) do
      0 ->
        poller(floor,button_type,:released)
      1->
        poller(floor,button_type,:pushed)
    end
end
end

defmodule FloorPoller do
  @moduledoc """
  A module for registrating a single event when a floorevent is beeing triggered in a
  sequence, eg. the floor sensor is high when a floor is reached and the lift stays
  at the floor.

  The state machine starts of in :idle-state which means the sensor has triggered
  an event and is now to wait for the next thing to happen. If
  get_floor_sensor_state isn't high, the lift is inbetween floors. If not, the
  :idle-state loops.

  When a lift is between two floors, the result from Driver.get_floor_sensor_state
  is used as an argument for poller(). If Driver.get_floor_sensor_state returns
  an int, the function PollerServer.at_floor is called and the state is set to
  :idle.
  """

  use Task

  def start_link(floor_info) do
    Task.start_link(__MODULE__, :floor_poll, [floor_info])
  end

  def child_spec([id|floor_info]) do
    %{id: id,
      start: {__MODULE__,:start_link,[floor_info]},
      restart: :permanent,
      type: :worker
    }
  end

  #State transitions
  def poller(:idle) do
    :timer.sleep(200)
    case Driver.get_floor_sensor_state() do
      :between_floors ->
        poller(:between_floors)
      _other->
        poller(:idle)
    end
  end

  def poller(:between_floors) do
    :timer.sleep(200)
    poller(Driver.get_floor_sensor_state())
  end

  def poller(floor) do
    PollerServer.at_floor(floor)
    poller(:idle)
  end
end
