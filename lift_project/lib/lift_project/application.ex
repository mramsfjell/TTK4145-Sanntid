defmodule LiftProject.Application do
  @moduledoc """
  
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
