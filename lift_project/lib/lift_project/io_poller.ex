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

  def handle_cast {:new_order, order}, [] do

    OrderDistribution.new_order(order)
    {:noreply, []}
  end

  def handle_cast {:at_floor, floor}, [] do
    Lift.at_floor(floor)
    {:noreply, []}
  end
end

defmodule ButtonPoller.Supervisor do
  use Supervisor

  def start_link (floors) do
    Supervisor.start_link(__MODULE__,{:ok,floors},[name: Button.Supervisor])
  end


 # 
  def init({:ok,[floors]}) do
    children = Enum.flat_map(0..(floors-1), fn floor ->
      child =

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
end


defmodule FloorPoller do
  @moduledoc """

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
