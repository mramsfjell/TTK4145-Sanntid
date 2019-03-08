defmodule Order do
  @moduledoc """
  
  """

  @valid_order [:hall_down, :cab, :hall_up]
  @valid_floor 0..3
  @enforce_keys [:floor,:button_type]
  defstruct [:floor,:button_type,:time,node: nil,watch_dog: nil]

  def new(floor,button_type)
    when floor in @valid_floor and  button_type in @valid_order
    do
      %Order{
        floor: floor,
        button_type: button_type,
        time: Time.utc_now()|> Time.truncate(:second),
        node: Node.self
      }
  end


defmodule OrderDistribution do
  @moduledoc """

  """

  use GenServer

  def assign_watchdog(order) when Node.list == [] do
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
      {node,_min_cost} = calculate_assignment(replies)
      Map.put(order,:node,node)
    end
  end

  def calculate_assignment(replies) do
    {node, min_cost} = Enum.min_by(replies, fn({node,cost}) -> cost end)
  end

  def timestamp(order)do
    timestamp = Time.utc_now |> Time.truncate(:millisecond)
    Map.put(order,:time,timestamp)
  end

  def broadcast_result (order) do
    order = assign_node(order)
    |> assign_watchdog(order)
    |> timestamp(order)
    GenServer.multi_call(:distribute_result, order)
  end

end
