defmodule Elevator.Orderlist do
  use GenServer

  @order_ttl 5_000 #milliseconds

  #Orderlist layout
  #%{up: [0 0 0 0], down: [0 0 0 0], cab: [0 0 0 0]}

  def start_link(floors) when is_integer(floors) do
    GenServer.start_link(__MODULE__, %{floors: floors}, [name: :order_list])
  end


  def add(pid,floor,button_type)when is_integer(floor) and is_atom(button_type) do
    if button_type == :cab or button_type == :hall_down or button_type == :hall_up   do
      GenServer.call(pid, {:add,floor,button_type})
    else
      {:error,:invalid_direction}
    end
  end

  def remove(pid,floor,direction) when is_integer(floor) and is_atom(direction) do
    if direction == :up or direction == :down do
      GenServer.call(pid, {:remove,floor,direction})
    else
      {:error,:invalid_direction}
    end
  end

  def get_orders(pid) do
    GenServer.call(pid,{:get})
  end

  def order_at_floor?(pid,floor,direction) when is_integer(floor) and is_atom(direction) do
    GenServer.call(pid,{:get,floor,direction})
  end

  def stop(pid) do
    GenServer.stop(pid)
  end

  #Consistency tests
  defp schedule_old_order_check do
    Process.send_after(self(), :old_order_check, Integer.floor_div(@order_ttl,2))
  end

  #Helper functions
  defp get_order_list_element(floor,button_type,state) do
    get_in(state,[:orders,button_type]) |> Enum.fetch!(floor)
  end

  defp update_order_list_element(floor,button_type,value,state) do
    time_stamp = Time.utc_now()|> Time.truncate(:second)
    state
    |> get_in([:orders,button_type])
    |> List.update_at(floor, &(&1 = {value,time_stamp}))
  end

  defp check_order({_value,time}) do
    time_out_treshold = Time.utc_now() |> Time.add(-1*@order_ttl)
    case Time.compare(time_out_treshold, time) do
      :lt ->
        true
      _ -> false
    end
  end

  defp check_order_list(orders) do
    orders |> Enum.filter(fn {value,time} -> true end)
  end




  #Callbacks

  def init(state) do
    time_stamp = Time.utc_now()|> Time.truncate(:millisecond)
    init_order_list = List.duplicate({0,time_stamp}, state.floors)
    orders = %{
      cab: init_order_list,
      hall_up: init_order_list,
      hall_down: init_order_list
    }
    new_state = state |> Map.put(:orders,orders)
    schedule_old_order_check
    {:ok,new_state}
  end

  def handle_call({:add,floor,button_type},_from, state) do
    if 0 <= floor and floor < state.floors do
      new_list = update_order_list_element(floor,button_type,1,state)
      new_state = put_in(state,[:orders,button_type],new_list)
      new_state |> inspect |> IO.puts
      {:reply,:ok,new_state}
    else
      {:reply,{:error,:nonexistent_floor},state}
    end
  end


  def handle_call({:get},_from, state) do
    {:reply,{:ok,state.orders},state}
  end

  def handle_call({:get,floor,direction},_from,state) do
    order? =
    case direction do
      :up ->
        {hall_order,_time} = get_order_list_element(floor,:hall_up,state)
        {cab_order,_time} = get_order_list_element(floor,:cab,state)
        hall_order == 1 or cab_order == 1
      :down ->
        {hall_order,_time} = get_order_list_element(floor,:hall_down,state)
        {cab_order,_time} = get_order_list_element(floor,:cab,state)
        hall_order == 1 or cab_order == 1
    end
    {:reply,order?,state}
  end

  def handle_call({:remove,floor,direction},_from,state) do
    if 0 <= floor and floor < state.floors do
      time_stamp = Time.utc_now()|> Time.truncate(:millisecond)
      new_state =
        case direction do
          :up ->
            new_list = update_order_list_element(floor,:hall_up,0,state)
            put_in(state,[:orders,:hall_up],new_list)
          :down ->
            new_list = update_order_list_element(floor,:hall_down,0,state)
            put_in(state,[:orders,:hall_down],new_list)
        end
      cab_list = update_order_list_element(floor,:cab,0,state)
      new_state = put_in(new_state,[:orders,:cab],cab_list)
      IO.puts inspect new_state.orders
      {:reply,:ok,new_state}
    else
      {:reply,{:error,:nonexistent_floor},state}
    end
  end

  def handle_info(:old_order_check,state) do
    time_out_treshold = Time.utc_now() |> Time.add(-1*@order_ttl)
    for {button_type,orders} <- state.orders, fn {time,value} -> v==1 end, do:
      #for {value,time} <- order_list, do:
      IO.puts("Orderlist contains old order"
  schedule_old_order_check()
  {:noreply,state}
  end
end
