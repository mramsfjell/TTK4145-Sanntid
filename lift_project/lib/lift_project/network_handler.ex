defmodule NetworkHandler do
  use Supervisor

  def start_link([recv_port]) do
    Supervisor.start_link(__MODULE__,[recv_port], name: :network_handler)
  end

  def init([recv_port]) do
    children = [
      {UDP.Server,[recv_port]},
      {UDP.Client,[recv_port]}
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end
end

defmodule UDP.Client do
  use Task
  def start_link(port) do
    Task.start_link(__MODULE__,:init,port)
  end

  def init(port) do
    {:ok,socket} = :gen_udp.open(port,[:binary,active: false,broadcast: true])
    IO.puts("UDP listen started at port #{port}")
    listen(socket)
  end

  def listen(socket) do
    {:ok,{_ip,_port,node_name}} = :gen_udp.recv(socket, 0)
    #IO.puts(node_name)

    if node_name not in ([Node.self|Node.list]|> Enum.map(&(to_string(&1)))) do
      IO.puts "connecting to node #{node_name}"
      Node.ping(String.to_atom(node_name))
    end

    listen(socket)
  end
end

defmodule UDP.Server do
  @sub_net {255,255,255,255}
  @broadcast_intervall 1_000
  use Task
  def start_link(ports) do
    Task.start_link(__MODULE__,:init,ports)
  end

  def init(recv_port) do
    {:ok,socket} = :gen_udp.open(0,[:binary, active: false,broadcast: true])
    IO.puts "UDP broadcast started"
    broadcast(socket,recv_port)
  end

  def broadcast(socket,recv_port) do
    :gen_udp.send(socket, @sub_net, recv_port, to_string(Node.self))
    Process.sleep(@broadcast_intervall)
    broadcast(socket,recv_port)
  end
end
