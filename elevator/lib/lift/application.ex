 defmodule Elevator.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    :os.cmd 'xterm -e ElevatorServer'
    # List all child processes to be supervised
    children = [
      # Starts a worker by calling: Elevator.Worker.start_link(arg)
      # {Elevator.Worker, arg}
    ]
    {:ok,driver_pid} = Driver.start
    {:ok,lift_pid} = Lift.FSM.start_link(self(),driver_pid)
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    #opts = [strategy: :one_for_one, name: Elevator.Supervisor]
    #Supervisor.start_link(children, opts)
  end
end
