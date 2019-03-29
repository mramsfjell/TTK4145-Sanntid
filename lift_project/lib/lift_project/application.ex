defmodule LiftProject.Application do
  @moduledoc """
  This is considered to be the entry point of the project.

  The system consists of the following modules:
  - Lift
  - Driver
  - FloorPoller
  - ButtonPoller
  - OrderDistribution
  - Auction
  - NodeDiscovery.Listen
  - NodeDiscovery.Broadcast
  - OrderServer
  - WatchDog
  """

  use Application
  @floors 4

  def start(_type, _args) do
    children = [
      {Liftproject.Supervisor, []}
    ]

    opts = [strategy: :one_for_one, name: LiftProject.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
