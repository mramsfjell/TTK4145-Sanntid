defmodule Elevator.Orderlist do
  use GenServer

  @order_ttl 60_000 #milliseconds
  @name :order_list
  #Orderlist layout
  #%{active: [orders], complete: [orders], :oder_count integer, :floors}

  def start_link([floors]) when is_integer(floors) do
    GenServer.start_link(__MODULE__, %{floors: floors}, [name: @name])
  end


  def add(floor,button_type)
  when is_integer(floor) and is_atom(button_type)
  do
    GenServer.call(@name, {:add,floor,button_type})
  end

  def remove(floor,direction)
  when is_integer(floor) and is_atom(direction)
  do
    GenServer.call(@name, {:remove,floor,direction})
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
      active: [],
      complete: [],
      floors: config.floors,
      order_count: 0
    }
    {:ok,new_state}
  end

  def handle_call({:add,floor,button_type},_from, state) do
    case Order.new(floor,button_type) do
      {:error,_} ->
        {:reply,{:error,:nonexistent_floor},state}
      order ->
        new_state =
          state
          |> Map.update!(:active,&([order|&1]))
          |> Map.update!(:order_count, &(&1+1))
        {:reply,:ok,new_state}
    end
  end

  def handle_call({:remove,floor,direction},_from,state) do
    #IO.puts inspect(state.active)
    completed_orders = state.active |> Enum.filter(&(order_at_floor(&1,floor,direction)))
    active_orders = state.active -- completed_orders
    new_state =
    if length(completed_orders) > 0 do
      state
        |> Map.put(:active,active_orders)
        |> Map.update!(:complete,&([completed_orders|&1]))
        |> Map.update!(:order_count, &(&1-length(completed_orders)))
    end
    IO.puts(inspect(state))
    {:reply,:ok,new_state}
  end


  def handle_call({:get},_from, state) do
    {:reply,{:ok,state.active},state}
  end

  def handle_call({:get,floor,direction},_from,state) do
    order? = state.active
    |> Enum.any?(&(order_at_floor(&1,floor,direction)))
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
  def new(_floor,_button_type) do
    {:error,:invalid_order}
  end
end
