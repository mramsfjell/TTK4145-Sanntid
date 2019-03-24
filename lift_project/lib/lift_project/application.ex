defmodule LiftProject.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  @floors 4

  def start(_type, _args) do
    children = [
      {Driver, []},
      {Lift, []},
      {OrderDistribution, []},
      {WatchDog, []},
      {ButtonPoller.Supervisor, [@floors]},
      {FloorPoller, [:floor]},
      {NetworkHandler, [22_010]},
      {Task.Supervisor, name: Auction.Supervisor},
      {OrderServer, []}
      # Starts a worker by calling: LiftProject.Worker.start_link(arg)
      # {LiftProject.Worker, arg}
    ]

    NetworkInitialization.boot_node("n", 1_000)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported optionsS
    opts = [strategy: :one_for_one, name: LiftProject.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
