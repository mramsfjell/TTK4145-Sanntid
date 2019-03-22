defmodule OrderDistribution do
  @moduledoc """
  This module takes care of distributing orders,
  both new orders from I/O and reinjected orders from WatchDog.
  """
  use GenServer

  @name :order_distribution
  @valid_orders [:hall_down, :cab, :hall_up]

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  # API ----------------------------------------------------------

  @doc """
  Reinjected order from WatchDog.
  """
  def new_order(order = %Order{}) do
    GenServer.call(@name, {:new_order, order})
  end

  @doc """
  New order from I/O.
  """
  def new_order(floor, button_type)
      when is_integer(floor) and button_type in @valid_orders do
    order = Order.new(floor, button_type)
    new_order(order)
  end

  # Callbacks ----------------------------------------------------

  def init(_args) do
    {:ok, %{}}
  end

  def handle_call({:new_order, order}, _from, state) do
    execute_auction(order)
    {:reply, :ok, state}
  end

  # Helper functions -----------------------------------------------------

  def assign_watchdog(order, [] = node_list) do
    Map.put(order, :watch_dog, Node.self())
  end

  def assign_watchdog(order, node_list) do
    watch_dog =
      ([Node.self() | node_list] -- [order.node])
      |> Enum.random()

    Map.put(order, :watch_dog, watch_dog)
  end

  def execute_auction(%{button_type: :cab} = order) do
    IO.inspect(order)
    find_lowest_bidder([order.node], order)
  end

  def execute_auction(order) do
    find_lowest_bidder([Node.self() | Node.list()], order)
  end

  def find_lowest_bidder(nodes, order) do
    {bids, _bad_nodes} =
      GenServer.multi_call(nodes, :order_server, {:evaluate_cost, order}, 1_000)

    IO.inspect(bids)

    case check_valid_bids(bids) do
      :already_complete ->
        :ok

      :valid ->
        {winner_node, _min_cost} = filter_lowest_bidder(bids)
        post_process_auction(order, winner_node)
    end
  end

  def check_valid_bids(bids) do
    case(Enum.any?(bids, fn {_node, reply} -> {:completed, 0} == reply end)) do
      true -> :already_complete
      false -> :valid
    end
  end

  def filter_lowest_bidder(bids) do
    {winner_node, min_bids} =
      Enum.min_by(bids, fn {node_name, cost} -> cost end, fn -> {Node.self(), 0} end)
  end

  def post_process_auction(order, winner_node) do
    IO.puts("result")

    order
    |> Map.put(:node, winner_node)
    |> assign_watchdog(Node.list())
    |> IO.inspect()
    |> broadcast_result
  end

  def broadcast_result(order) do
    GenServer.multi_call(:order_server, {:new_order, order})
    Node.spawn_link(order.watch_dog, WatchDog, :new_order, [order])
  end
end
