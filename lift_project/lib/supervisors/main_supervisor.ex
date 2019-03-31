defmodule Liftproject.Supervisor do
  use Supervisor
  @floors 4
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    children = [
      {HardwareSupervisor, [@floors]},
      {NodeDiscovery.Supervisor, [22_010]},
      {WatchDog, []},
      {OrderDistribution.Supervisor, []},
      {OrderServer, []}
    ]

    opts = [strategy: :one_for_one]
    Supervisor.init(children, opts)
  end
end
