defmodule OrderDistribution do
  @moduledoc """
  Queueing for execution of auctions

  Uses the following modules:
  - Order
  - Watchdog
  """
  use GenServer

  @name :order_distribution
  @valid_orders [:hall_down, :cab, :hall_up]

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  # API ------------------------------------------------------------------------

  @doc """
  Assign and distribute an order to the system.
  """
  def new_order(order = %Order{}) do
    GenServer.cast(@name, {:new_order, order})
  end

  @doc """
  Assign and distribute an order to the system.
  """
  def new_order(floor, button_type)
      when is_integer(floor) and button_type in @valid_orders do
    order = Order.new(floor, button_type)
    new_order(order)
  end

  # Callbacks ------------------------------------------------------------------

  def init(_args) do
    {:ok, %{}}
  end

  def handle_cast({:new_order, order}, state) do
    {:ok, _auction} = Auction.Supervisor.start_child(order)
    {:noreply, state}
  end
end

defmodule Auction do
  @moduledoc """
  Task for finding wich lift should get an order, and distribute the result of the auction
  to all nodes in the cluster

  Uses the following modules:
  - Order
  - Watchdog
  """

  use Task

  @auction_timeout 1_000

  def start_link(order) do
    Task.start_link(__MODULE__, :execute_auction, [order])
  end

  def child_spec(order) do
    %{
      id: "auction",
      start: {__MODULE__, :start_link, [order]},
      restart: :transient,
      type: :worker
    }
  end

  @doc """
  Executes an edge case auction for the specified order. As this is a cab order,
  the only allowed winner of the auction is the node that called the order.
  """
  def execute_auction(%{button_type: :cab} = order) do
    execute_auction(order, [order.node])
  end

  @doc """
  Executes an auction to find the lift among the active nodes with lowest cost
  for the specified order.
  """
  def execute_auction(order) do
    execute_auction(order, [Node.self() | Node.list()])
  end

  def execute_auction(order, valid_nodes) do
    with {winner_node, _cost} <- find_lowest_bidder(valid_nodes, order) do
      complete_order =
        order
        |> Map.put(:node, winner_node)
        |> assign_watchdog(valid_nodes)

      :ok = broadcast_result(complete_order)
    else
      {:already_complete} -> :ok
    end
  end

  defp assign_watchdog(order, node_list) when length(node_list) <= 1 do
    Map.put(order, :watch_dog, order.node)
  end

  defp assign_watchdog(order, node_list) when length(node_list) > 1 do
    watch_dog =
      (node_list -- [order.node])
      |> Enum.random()

    Map.put(order, :watch_dog, watch_dog)
  end

  defp find_lowest_bidder(nodes, order) do
    {bids, _bad_nodes} =
      GenServer.multi_call(nodes, :order_server, {:evaluate_cost, order}, @auction_timeout)

    case check_completed?(bids) do
      true -> {:already_complete}
      false -> filter_lowest_bidder(bids)
    end
  end

  defp check_completed?(bids) when length(bids) > 0 do
    Enum.any?(bids, fn {_node, reply} -> {:completed, 0} == reply end)
  end

  defp filter_lowest_bidder(bids) do
    {winner_node, min_bid} =
      Enum.min_by(bids, fn {_node_name, cost} -> cost end, fn -> {Node.self(), 0} end)
  end

  defp post_process_auction(order, winner_node) do
    order
    |> Map.put(:node, winner_node)
    |> assign_watchdog(Node.list())
  end

  def broadcast_result(order) do
    GenServer.multi_call(
      [Node.self() | Node.list()],
      :order_server,
      {:new_order, order},
      @auction_timeout
    )

    Node.spawn_link(order.watch_dog, WatchDog, :new_order, [order])
    :ok
  end
end
