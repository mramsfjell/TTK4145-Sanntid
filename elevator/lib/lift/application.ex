 defmodule Elevator.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    #:os.cmd 'xterm -e ElevatorServer'
    Node.set_cookie(:group_64)
    # List all child processes to be supervised
    #{:ok,driver_pid} = Driver.start_link
    #{:ok,lift_pid} = Lift.FSM.start_link()
    #Button.Supervisor.start_link([4])

    children = [
      {Driver,[]},
      {Lift.FSM,[]},
      {Button.Supervisor,[4]},
      {NetworkHandler,[34_432,35_543]},
      {Elevator.Orderlist,[4]}
      #{Driver,[]}
      #{Driver,[]},
      #{Lift.FSM,[]},
      #{Button.Supervisor,[4]}
      # Starts a worker by calling: Elevator.Worker.start_link(arg)
      # {Elevator.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Elevator.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
