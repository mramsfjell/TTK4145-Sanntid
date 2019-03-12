defmodule Elevator.Orderlist do
  use GenServer

  @order_ttl 60_000 #milliseconds
  @name :order_list
  #Orderlist layout
  #%{active: %{node%{time%{order}}}, complete: %{node%{time%{order}}}, :floors}


  def start_link([floors]) when is_integer(floors) do
    GenServer.start_link(__MODULE__, %{floors: floors}, [name: @name])
  end


  def add(order) do
    GenServer.call(@name, {:add,order})
  end

  def order_done(order) do
    GenServer.multi_call([Node.self|Node.list],@name, {:order_done,order})
  end

  def get_orders() do
    GenServer.call(@name,{:get})
  end

  def get_orders_at_floor(floor,direction)
  when is_integer(floor) and is_atom(direction)
  do
    GenServer.call(@name,{:get,floor,direction})
  end

  def order_complete?(order) do
    GenServer.call(@name, {:get,order})
  end

  def stop() do
    GenServer.stop(@name)
  end

  #Consistency tests
  defp schedule_old_order_check do
    Process.send_after(self(), :old_order_check, Integer.floor_div(@order_ttl,2))
  end

  #Helper functions
  defp order_at_floor(order,floor,direction) do
    order.floor == floor and
    case direction do
      :up ->
        order.button_type == :cab or
        order.button_type == :hall_up
      :down ->
        order.button_type == :cab or
        order.button_type == :hall_down
    end
  end

  #Callbacks
  def init(config) do
    new_state = %{
      active: %{Node.self => %{}},
      complete: %{Node.self => %{}},
      floors: config.floors,
    }
    :net_kernel.monitor_nodes(true)
    {:ok,new_state}
  end

  def handle_call({:add,order},_from, state) do
    new_state =
    if  Map.has_key?(state.active, order.node) do
      put_in(state, [:active,order.node,order.time],order)
    else
      put_in(state, [:active,order.node], %{order.time => order})
    end
    {:reply,:ok,new_state}
  end

  def handle_call({:order_done,order},_from,state) do
    new_state =
    case pop_in(state, [:active,order.node,order.time]) do
      {nil,state} ->
        IO.puts "non existent order"
        state
      {_complete_order,new_state} ->
        IO.puts "order removed"
        if  Map.has_key?(new_state.complete, order.node) do
          put_in(new_state, [:complete,order.node,order.time],order)
        else
          put_in(new_state, [:complete,order.node], %{order.time => order})
        end
    end
    IO.puts(inspect(new_state))
    {:reply,:ok,new_state}
  end


  def handle_call({:get},_from, state) do
    {:reply,{:ok,state},state}
  end

  def handle_call({:get,floor,direction},_from,state) do
    orders = get_in(state,[:active,Node.self])
      |> Map.values
      |> Enum.filter(fn(order_list) -> order_at_floor(order_list,floor,direction) end)
    {:reply,orders,state}
  end

  def handle_call({:get,order},_from,state) do
    complete? = order in (get_in(state, [:complete,order.node]) |> Map.values)
    {:reply,complete?,state}
  end

  def handle_info({:nodedown, node},state) do
    case pop_in(state,[:active,node]) do
      {node_orders,state} ->
        responsible = Enum.filter(node_orders, &(&1.watch_node == Node.self))
        Enum.each(responsible, fn order->
          case order.button_type do
            :cab -> 1
            oter ->
              IO.puts("add order to Auction")
              Process.sleep(500)
              IO.puts("order added")
            end
          end
      )
  end
end

end


defmodule Order do
  @valid_order [:hall_down, :cab, :hall_up]
  @valid_floor 0..3
  @enforce_keys [:floor,:button_type]
  defstruct [:floor,:button_type,:time,node: nil,watch_node: nil]

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

  def is_valid(order) do
    true
  end

  def new(_floor,_button_type) do
    {:error,:invalid_order}
  end
end

#def dustribute(order)
#when Order.is_valid(order) do
#GenServer.multi_call(Lift,{:get_cost,order})
