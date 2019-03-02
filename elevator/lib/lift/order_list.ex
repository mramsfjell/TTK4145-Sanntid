defmodule Elevator.Orderlist do
  use GenServer

  @order_ttl 60_000 #milliseconds
  @name :order_list
  #Orderlist layout
  #%{active: %{node%{time%{order}}}, complete: %{node%{time%{order}}}, :floors}

  #Orderlist layout
  #%{active: [orders], complete: [orders], :floors}

  def start_link([floors]) when is_integer(floors) do
    GenServer.start_link(__MODULE__, %{floors: floors}, [name: @name])
  end


  def add(order) do
    GenServer.call(@name, {:add,order})
  end

  def order_done(order) do
    GenServer.call(@name, {:order_done,order})
  end

  def get_orders() do
    GenServer.call(@name,{:get})
  end

  def order_at_floor?(floor,direction)
  when is_integer(floor) and is_atom(direction)
  do
    GenServer.call(@name,{:get,floor,direction})
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
      active_self: [],
      complete: [],
      active_system: [],
      floors: config.floors,
    }
    {:ok,new_state}
  end

  def handle_call({:add,order},_from, state) do
    new_state =
    if order.node == Node.self do
      state |> Map.update!(:active_self,&([order|&1]))
    else
      state |> Map.update!(:active_system,&([order|&1]))
    end
    {:reply,:ok,new_state}
  end

  def handle_call({:order_done,order},_from,state) do
    order_list =
    if order.node ==  Node.self do
      :active_self
    else
      :active_system
    end
    completed_orders = state |> Map.get(order_list) |> Enum.filter(&(&1 == order))
    active_orders = Map.get(state,order_list) -- completed_orders
    new_state =
    if length(completed_orders) > 0 do
      state
        |> Map.put(order_list,active_orders)
        |> Map.update!(:complete,&([completed_orders|&1]))
    end
    IO.puts(inspect(state))
    {:reply,:ok,new_state}
  end


  def handle_call({:get},_from, state) do
    {:reply,{:ok,state},state}
  end

  def handle_call({:get,floor,direction},_from,state) do
    order? = state.active_self
    |> Enum.any?(&(order_at_floor(&1,floor,direction)))
    {:reply,order?,state}
  end
end

defmodule Order do
  @valid_order [:hall_down, :cab, :hall_up]
  @valid_floor 0..3
  @enforce_keys [:floor,:button_type]
  defstruct [:floor,:button_type,:time_stamp,node: nil,watch_node: nil]

  def new(floor,button_type)
    when floor in @valid_floor and  button_type in @valid_order
    do
      %Order{
        floor: floor,
        button_type: button_type,
        time_stamp: Time.utc_now()|> Time.truncate(:second),
        node: Node.self
      }
  end
  def new(_floor,_button_type) do
    {:error,:invalid_order}
  end
end
