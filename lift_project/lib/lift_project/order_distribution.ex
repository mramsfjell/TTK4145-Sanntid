defmodule Order do
  @moduledoc """

  """

  @valid_orders [:hall_down, :cab, :hall_up]
  @enforce_keys [:floor,:button_type]
  defstruct [:floor,:button_type,time: nil,node: nil,watch_dog: nil]

  def new(floor,button_type)
    when is_integer(floor) and  button_type in @valid_orders
    do
      %Order{
        floor: floor,
        button_type: button_type
      }
  end


defmodule OrderDistribution do
  @moduledoc """
  This module takes care of distributing orders, both from IO and WatchDog.

  """

  # Need to be changed to Task if we want to handle several auctions at once
  use GenServer
  @name :order_distribution

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  def new_order(order = %Order{}) do
    GenServer.call(@name, {:new_order,order})
  end

  def new_order(floor, button_type)
    when is_integer(floor) and button_type in @valid_orders
    do
      order = Order.new(floor,button_type)
      GenServer.call(@name, {:new_order,order})
  end


  # Callbacks

  def handle_call({:new_order,order}) do
    if order.button_type == :cab do
      Map.put(order,:node,Node.self)
    else
      assign_node(order)
    end
    order
      |> assign_watchdog
      |> timestamp
      |> broadcast_result
  end


  # Helper functions

  def assign_watchdog(order)
    when Node.list == []
    do
      Map.put(order,:watch_dog,Node.self)
  end

  def assign_watchdog(order) do
    watch_dog =
      [Node.self|Node.list] -- order.node
      |> Enum.random()
    Map.put(order,:watch_dog,watch_dog)
  end

  def assign_node(order) do
    with
      {replies, _bad_nodes} <- GenServer.multi_call(:evaluate_cost, order)
    do
      {node,_min_cost} = find_lowest_cost(replies)
      Map.put(order,:node,node)
    end
  end

  def find_lowest_cost(replies) do
    {node, min_cost} = Enum.min_by(replies, fn({node,cost}) -> cost end)
  end

  def timestamp(order)do
    timestamp = Time.utc_now |> Time.truncate(:millisecond)
    Map.put(order,:time,timestamp)
  end

  def broadcast_result(order) do
    GenServer.multi_call(:distribute_result, order)
  end

end
