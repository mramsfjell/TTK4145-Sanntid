defmodule Elevator.Orderlist do
  use GenServer

  #Orderlist layout
  # [u0, u1, u2, d3, d2, d1,c0,c1,c2,c3]
  #%{up: [0 0 0 0], down: [0 0 0 0], cab: [0 0 0 0]}

  def start_link(floors) do
    GenServer.start_link(__MODULE__, %{floors: floors, orders: []}, [name: :order_list])
  end


  def add(server,floor,direction) do
    GenServer.call(server, {:edit,floor,direction,1})
  end

  def remove(server,floor,direction) do
    GenServer.call(server, {:edit,floor,direction,0})
  end

  def get_orders(server) do
    GenServer.call(server,{:get})
  end

  def get_order(server,floor,direction) do
    GenServer.call(server,{:get,floor,direction})
  end

  def stop(server) do
    GenServer.stop(server)
  end

  #Helper function
  defp get_order_list_index(state,floor,direction) do
    case direction do
      :down -> state.floors*2 - floor-1
      :up -> floor
    end
  end

  #Callbacks

  def init(state) do
    empty_orderlist = List.duplicate(0,(state.floors*2-2))
    new_state = state |> Map.replace!(:orders, empty_orderlist)
    {:ok,new_state}
  end

  def handle_call({:edit,floor,direction,value},_from, state) do
    if 0 <= floor and floor < state.floors do
      order_list_index = get_order_list_index(state,floor,direction)
      new_orders = List.insert_at(state.orders, order_list_index , value)
      new_state = Map.replace!(state, :orders, new_orders)
      {:reply,:ok,new_state}
    else
      {:reply,{:error,:nonexistent_floor},state}
    end
  end

  def handle_call({:get},_from, state) do
    {:reply,{:ok,state.orders},state}
  end

  def handle_call({:get,floor,direction},_from,state) do
    index = get_order_list_index(state,floor,direction)
    order = state.orders |> Enum.fetch(index)
    {:reply,order,state}
  end

end
