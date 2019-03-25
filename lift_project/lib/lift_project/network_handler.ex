defmodule NetworkHandler do
  @moduledoc """
  Module for supervising the listening and broadcasting via UDP.
  """
  use Supervisor

  def start_link([recv_port]) do
    Supervisor.start_link(__MODULE__, [recv_port], name: :network_handler)
  end

  def init([recv_port]) do
    children = [
      {UDP.Server, [recv_port]},
      {UDP.Client, [recv_port]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

defmodule NetworkInitialization do
  @moduledoc """
  Initializes the node by fetching IP and setting name, cookie and tick_time.
  """

  @doc """
  Credited: Jostein Løwer. https://github.com/jostlowe/kokeplata/tree/master/lib (24.03.19)
  Boots a node with a specified tick time. node_name sets the node name before @.
  The IP-address is automatically imported.
      iex> NetworkInitialization.boot_node "n1"
      {:ok, #PID<0.12.2>}
      iex(n1@10.100.23.253)> _
  """
  def boot_node(node_name, tick_time \\ 15_000) do
    ip = get_my_ip() |> ip_to_string()
    full_name = node_name <> "@" <> ip
    Node.start(String.to_atom(full_name), :longnames, tick_time)
    Node.set_cookie(:Daarlig_luft)
  end


  @doc """
  Credited: Jostein Løwer. https://github.com/jostlowe/kokeplata/tree/master/lib (24.03.19)
  Returns the ip address of our network interface.
  ## Examples
      iex> NetworkInitialization.get_my_ip
      {10, 100, 23, 253}
  """
  def get_my_ip(counter \\ 0) when counter < 11 do
    Process.sleep(100)
    if counter == 10 do
      IO.puts("Couldn't find my IP")
    end

    {:ok, socket} = :gen_udp.open(6199, active: false, broadcast: true)
    :ok = :gen_udp.send(socket, {255, 255, 255, 255}, 6199, "Test packet")

    ip =
      case :gen_udp.recv(socket, 100, 1000) do
        {:ok, {ip, _port, _data}} -> ip
        {:error, _} -> get_my_ip(counter + 1)
      end

    :gen_udp.close(socket)
    ip
  end

@doc """
Credited: Jostein Løwer. https://github.com/jostlowe/kokeplata/tree/master/lib (24.03.19)
"""
  def ip_to_string(ip) do
    :inet.ntoa(ip) |> to_string()
  end
end

defmodule UDP.Client do
  @moduledoc """
  Module for listening for other nodes via UDP.
  """
  use Task

  def start_link(port) do
    Task.start_link(__MODULE__, :init, port)
  end

  def init(port) do
    {:ok, socket} = :gen_udp.open(port, [:binary, active: false, broadcast: true])
    IO.puts("UDP listen started at port #{port}")
    listen(socket)
  end

  def listen(socket) do
    {:ok, {_ip, _port, node_name}} = :gen_udp.recv(socket, 0)
    # IO.puts(node_name)

    if node_name not in ([Node.self() | Node.list()] |> Enum.map(&to_string(&1))) do
      IO.puts("connecting to node #{node_name}")
      Node.ping(String.to_atom(node_name))
    end

    listen(socket)
  end
end

defmodule UDP.Server do
  @moduledoc """
  Module for broadcasting to other nodes via UDP.
  """
  @sub_net {255, 255, 255, 255}
  @broadcast_intervall 1_000
  use Task

  def start_link(ports) do
    Task.start_link(__MODULE__, :init, ports)
  end

  def init(recv_port) do
    {:ok, socket} = :gen_udp.open(0, [:binary, active: false, broadcast: true])
    IO.puts("UDP broadcast started")
    broadcast(socket, recv_port)
  end

  def broadcast(socket, recv_port) do
    :gen_udp.send(socket, @sub_net, recv_port, to_string(Node.self()))
    Process.sleep(@broadcast_intervall)
    broadcast(socket, recv_port)
  end
end
