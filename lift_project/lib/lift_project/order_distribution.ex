defmodule OrderDistribution do
  @moduledoc """
  This module takes care of distributing orders, both new orders from I/O and reinjected orders from WatchDog.
  """
  use GenServer

  @name :order_distribution
  @valid_orders [:hall_down, :cab, :hall_up]

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  #Reinjected order from WatchDog
  def new_order(order = %Order{}) do
    GenServer.call(@name, {:new_order,order})
  end

  #New order from I/O
  def new_order(floor, button_type)
    when is_integer(floor) and button_type in @valid_orders
    do
      order = Order.new(floor,button_type)
      new_order(order)
  end


  # Callbacks

  def init(_args) do
    {:ok,%{}}
  end

  def handle_call({:new_order,order},_from,state) do
    new_order =
    if order.button_type == :cab do
      Map.put(order,:node,Node.self)
    else
      assign_node(order)
    end
    IO.puts("result")
    IO.inspect(new_order)
    new_order
      |> assign_watchdog(Node.list)
      #|> timestamp
      |> broadcast_result
      #|> Format node names(remoove all after @)
    {:reply,:ok,state}
  end


  # Helper functions

  def assign_watchdog(order, [] = node_list) do
      Map.put(order,:watch_dog,Node.self)
  end

  def assign_watchdog(order, node_list) do
    watch_dog =
      [Node.self|node_list] -- [order.node]
      |> Enum.random()
    Map.put(order,:watch_dog,watch_dog)
  end

  def assign_node(order) do
      {replies, _bad_nodes} = GenServer.multi_call(:order_server,{:evaluate_cost, order}) |> IO.inspect()
      {node_name,_min_cost} = find_lowest_cost(replies) |> IO.inspect
      Map.put(order,:node,node_name) |> IO.inspect
  end

  def find_lowest_cost(replies) do
    {node_name, min_cost} = Enum.min_by(replies, fn({node_name,cost}) -> cost end)
  end

  def broadcast_result(order) do
    GenServer.multi_call(:order_server, {:new_order, order})
  end
end