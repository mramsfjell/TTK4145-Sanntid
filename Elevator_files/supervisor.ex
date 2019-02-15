defmodule Button.Supervisor do
  use Supervisor

  def start_link (driver_pid) do
    Supervisor.start_link(__MODULE__,{:ok,driver_pid},[name: Button.Supervisor])
  end

  def init({:ok,driver_pid}) do
    IO.puts inspect(driver_pid)
    children = [
      Supervisor.child_spec({Button,{driver_pid,:hall_up,0}}, id: :u0),
      Supervisor.child_spec({Button,{driver_pid,:hall_up,1}}, id: :u1),
      Supervisor.child_spec({Button,{driver_pid,:hall_up,2}}, id: :u2),
      Supervisor.child_spec({Button,{driver_pid,:hall_down,1}}, id: :d1),
      Supervisor.child_spec({Button,{driver_pid,:hall_down,2}}, id: :d2),
      Supervisor.child_spec({Button,{driver_pid,:hall_down,3}}, id: :d3),
      Supervisor.child_spec({Button,{driver_pid,:cab,0}}, id: :c0),
      Supervisor.child_spec({Button,{driver_pid,:cab,1}}, id: :c1),
      Supervisor.child_spec({Button,{driver_pid,:cab,2}}, id: :c2),
      Supervisor.child_spec({Button,{driver_pid,:cab,3}}, id: :c3)
    ]
    opts = [strategy: :one_for_one, name: ElevatorTest.Superviso]
    Supervisor.init(children, opts)
  end
end
