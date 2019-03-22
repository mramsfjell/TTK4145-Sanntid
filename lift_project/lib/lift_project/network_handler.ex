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

  @doc """

  RETT FRA KOKEPLATA

  Returns (hopefully) the ip address of your network interface.
  ## Examples
      iex> UDP.Server.get_my_ip
      {10, 100, 23, 253}
  """

  def get_my_ip do
    {:ok, socket} = :gen_udp.open(6789, active: false, broadcast: true)
    :ok = :gen_udp.send(socket, {255, 255, 255, 255}, 6789, "test packet")

    ip =
      case :gen_udp.recv(socket, 100, 1000) do
        {:ok, {ip, _port, _data}} -> ip
        {:error, _} -> {:error, :could_not_get_ip}
      end

    :gen_udp.close(socket)
    ip
  end
end
