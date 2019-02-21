defmodule Elevator.Orderlist do
  use GenServer

  #Orderlist layout
  #%{up: [0 0 0 0], down: [0 0 0 0], cab: [0 0 0 0]}

  def start_link(floors) when is_integer(floors) do
    GenServer.start_link(__MODULE__, %{floors: floors}, [name: :order_list])
  end


  def add(pid,floor,button_type)when is_integer(floor) and is_atom(button_type) do
    GenServer.call(pid, {:add,floor,button_type})
  end

  def remove(pid,floor,direction) when is_integer(floor) and is_atom(direction) do
    GenServer.call(pid, {:remove,floor,direction})
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

  #Helper functions
  defp get_order_list_index(floor,button_type) do
    case button_type do
      :hall_up -> floor
      :cab -> floor
      :hall_down -> floor - 1
    end
  end

  #Callbacks

  def init(state) do
    orders = %{
      cab: List.duplicate(0, state.floors),
      hall_up: List.duplicate(0, state.floors),
      hall_down: List.duplicate(0, state.floors)
    }
    new_state = state |> Map.put(:orders,orders)
    {:ok,new_state}
  end

  def handle_call({:add,floor,button_type},_from, state) do
    if 0 <= floor and floor < state.floors do
      new_list = get_in(state,[:orders,button_type])
                 |> List.update_at(floor, &(&1 = 1))

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
        state.orders.hall_up |> Enum.fetch!(floor) == 1 or
        state.orders.cab |> Enum.fetch!(floor) == 1
      :down ->
        state.orders.hall_down |> Enum.fetch!(floor) == 1 or
        state.orders.cab |> Enum.fetch!(floor) == 1
    end
    {:reply,order?,state}
  end

  def handle_call({:remove,floor,direction},_from,state) do
    if 0 <= floor and floor < state.floors do
      new_state =
        case direction do
          :up ->
            new_list = state.orders.hall_up |> List.update_at(floor, &(&1 = 0))
            put_in(state,[:orders,:hall_up],new_list)
          :down ->
            new_list = state.orders.hall_down |> List.update_at(floor, &(&1 = 0))
            put_in(state,[:orders,:hall_down],new_list)
        end
      cab_list = state.orders.cab |> List.update_at(floor, &(&1 = 0))
      new_state = put_in(new_state,[:orders,:cab],cab_list)
      IO.puts inspect new_state.orders
      {:reply,:ok,new_state}
    else
      {:reply,{:error,:nonexistent_floor},state}
    end
  end
end
