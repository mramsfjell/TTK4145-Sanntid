defmodule TcpServer do
  def start(num,listen_port) do
    case :gen_tcp.listen(listen_port, [active: false,packet_size: 1024]) do
      {:ok,listen_socket} ->
        start_servers(num,listen_socket)
        {:ok,port} = :inet.port(listen_socket)
      {:error,reason} ->
        IO.puts("Error in tcp start")
        {:error,reason}
    end
  end

  def start_servers(0,_) do
    :ok
  end

  def start_servers(num,listen_socket) do
    Task.start(__MODULE__,:server,[listen_socket])
    start_servers(num-1,listen_socket)
  end

  def server(listen_socket) do
    case :gen_tcp.accept(listen_socket) do
      {:ok,socket} ->
        loop(socket)
      other ->
        IO.puts("Socket closed")
        :ok
    end
    server(listen_socket)
  end

  def loop(socket) do
    :inet.setopts(socket, [{:active,:once},:binary])
    receive do
      {:tcp,socket,data} ->
        IO.puts data
        :gen_tcp.send(socket, data)
        loop(socket)
      {:tcp_closed,socket} ->
        IO.puts("tcp_closed closed")
        :ok
      end
  end
end

defmodule TcpClient do
  @local_host {192, 168, 1, 6}
  @default_port 20_000
  def send(address,port,message) do
    {:ok,socket} = :gen_tcp.connect(address, port, [:binary, active: false,packet_size: 1024])
    :gen_tcp.send(socket, message)
    :gen_tcp.recv(socket,0) |> to_string |> IO.puts
    :gen_tcp.send(socket, message)
    :gen_tcp.recv(socket,0) |> to_string |> IO.puts
    :gen_tcp.close(socket)
  end

  def send(message) do
    send(@local_host,@default_port,message)
  end
end
