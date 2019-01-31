defmodule Udp do

    @default_server_port 20_013
    @local_host {255, 255, 255, 255}

    def launch_server do
        launch_server(@default_server_port)
    end

    def launch_server(port) do
        {:ok,socket} = :gen_udp.open(port)
        :inet.setopts(socket, [{:active, false}])
        :gen_udp.controlling_process(socket, self())
        
        IO.puts "Launching server on localhost on port #{port}"
        socket
    end

    def listen(socket) do
        {:ok,{ip,port,data}} = :gen_udp.recv(socket,0)
        IO.puts "#{inspect(data)}, from ip #{inspect(ip)} on port: #{inspect(port)}"
        listen(socket)
    end

    def send(data,socket,ip,port) do
        :gen_udp.send(socket,ip,port,data)
    end

end

