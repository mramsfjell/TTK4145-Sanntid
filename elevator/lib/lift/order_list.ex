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
  def order_at_floor(order,floor,direction) do
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
      active: [],
      complete: [],
      floors: config.floors,
      order_count: 0
    }
    {:ok,new_state}
  end

  def handle_call({:add,floor,button_type},_from, state) do
    case Order.new(floor,button_type) do
      :error ->
        {:reply,{:error,:nonexistent_floor},state}
      order ->
        state = Map.update!(state, :active,&([order|&1]))
        state = Map.update!(state, :order_count, &(&1+1))
        state |> inspect |> IO.puts
        {:reply,:ok,state}

    end
  end

  def handle_call({:remove,floor,direction},_from,state) do
    #IO.puts inspect(state.active)
    complete_orders = Enum.filter(state.active,&(order_at_floor(&1,floor,direction)))

    if length(complete_orders) > 0 do
      new_active = Enum.filter(state.active,)# Filter bort complete orders, så legg itl som under




     active_split_map = 
        state.active
        |> Enum.group_by(&(order_at_floor(&1,floor,direction)))
        |> Map.values()
      if 
          [new_active,matching_orders] ->
            IO.puts inspect new_active
            state = Map.put(state,:active,new_active)
            state = Map.put(state,:complete,[matching_orders|state.complete])
            state = Map.update!(state, :order_count, &(&1-1))
          other ->
            IO.puts(inspect(other)) 
            :ok
        end


    #IO.puts(inspect(state))
    {:reply,:ok,state}
  end


  def handle_call({:get},_from, state) do
    {:reply,{:ok,state.active},state}
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


end

defmodule Order do
  @valid_order [:hall_down, :cab, :hall_up]
  @valid_floor 0..3
  @enforce_keys [:floor,:button_type]
  defstruct [:floor,:button_type,:time_stamp,order_nr: nil] #node_id

  def new(floor,button_type)
    when floor in @valid_floor and  button_type in @valid_order
    do
      %Order{
        floor: floor,
        button_type: button_type,
        time_stamp: Time.utc_now()|> Time.truncate(:second),
        order_nr: nil
      }
  end

  def new(floor,button_type) do
    {:error,:invalid_order}
  end
end
