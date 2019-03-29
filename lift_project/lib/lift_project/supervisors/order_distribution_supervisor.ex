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