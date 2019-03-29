defmodule NodeDiscovery.Supervisor do
    use Supervisor
  
    def start_link([recv_port]) do
      Supervisor.start_link(__MODULE__, [recv_port], name: :network_handler)
    end
  
    def init([recv_port]) do
      children = [
        {NodeDiscovery.Listen, [recv_port]},
        {NodeDiscovery.Broadcast, [recv_port]}
      ]
  
      Supervisor.init(children, strategy: :one_for_one)
    end
end
  