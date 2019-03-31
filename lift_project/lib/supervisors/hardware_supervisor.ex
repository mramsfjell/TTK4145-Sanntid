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
  