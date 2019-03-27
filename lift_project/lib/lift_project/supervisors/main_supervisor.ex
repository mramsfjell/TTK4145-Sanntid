defmodule Liftproject.Supervisor do
  use Supervisor
  @floors 4
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    children = [
      {HardwareSupervisor, [@floors]},
      {NetworkHandler, [22_010]},
      {WatchDog, []},
      {OrderDistribution.Supervisor, []},
      {OrderServer, []}
    ]

    opts = [strategy: :one_for_one]
    Supervisor.init(children, opts)
  end
end

defmodule OrderDistribution.Supervisor do
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    children = [
      {OrderDistribution, []},
      {Task.Supervisor, name: Auction.Supervisor}
    ]

    opts = [strategy: :one_for_one]
    Supervisor.init(children, opts)
  end
end

defmodule HardwareSupervisor do
  use Supervisor

  def start_link(floors) do
    Supervisor.start_link(__MODULE__, floors, name: __MODULE__)
  end

  def init([floors]) do
    IO.inspect(floors)
    spawn(fn -> :os.cmd('xterm -e ElevatorServer') end)
    Process.sleep(100)

    children = [
      {Driver, []},
      {FloorPoller, [:floor]},
      {Lift, []},
      {ButtonPoller.Supervisor, [floors]}
    ]

    opts = [strategy: :rest_for_one]
    Supervisor.init(children, opts)
  end
end
