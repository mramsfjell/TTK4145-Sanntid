defmodule NetworkInitialization do
  @moduledoc """
  Initializes the node by finding IP adress and setting
  the name of the node, cookie and time until the node is dropped from the cluster
  if no heart beat messages are recieved.
  """

  # API ------------------------------------------------------------------------

  @doc """
  Credited: Jostein Løwer. https://github.com/jostlowe/kokeplata/tree/master/lib (24.03.19)
  Boots a node with a specified tick time. node_name sets the node name before @.
  The IP-address is automatically imported.
  """
  def boot_node(node_name, tick_time \\ 15_000) do
    ip = get_my_ip() |> ip_to_string()
    full_name = node_name <> "@" <> ip
    Node.start(String.to_atom(full_name), :longnames, tick_time)
    Node.set_cookie(:Daarlig_luft)
  end

  # Helper functions -----------------------------------------------------------

  # Credited: Jostein Løwer. https://github.com/jostlowe/kokeplata/tree/master/lib (24.03.19)
  defp get_my_ip(counter \\ 0) when counter < 11 do
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

  # Credited: Jostein Løwer. https://github.com/jostlowe/kokeplata/tree/master/lib (24.03.19)
  defp ip_to_string(ip) do
    :inet.ntoa(ip) |> to_string()
  end
end
