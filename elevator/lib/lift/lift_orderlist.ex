defmodule Lift do
  use GenServer

  defstruct     [:floor,:dir,:order]
  @enforce_keys [:floor,:dir,:state,:hall_up,:hall_down,:cab]
  @valid_dir    [:up,:down]
  @states       [:init,:idle,:mooving,:door_open]

  @name :Lift_FSM

  def start_link(args \\[4]) do
    GenServer.start_link(__MODULE__,args,[name: @name])
  end

  def at_floor(floor) do
    GenServer.cast(@name,{:at_floor,floor})
  end


  def new_order(floor,button_type)
  when is_integer(floor) and button_type in @valid_orders do
    GenServer.call(@name,{:new_order,floor,button_type})
  end

  def close_door() do
    Process.send(self,:close_door)
  end

  def get_state() do
    GenServer.call(@name,:get_state)
  end

  #Callbacs

  def init(args = [floors]) do
    case Driver.get_floor_sensor_state() do
      :between_floors ->
        data = new_list(floors,:up,:init)
        Driver.set_motor_direction(:up)
        {:ok,data}
      floor ->
        data = new_list(floors,floor,:up,:idle)
        {:ok,data}
      end
  end

  #Casts
  def handle_cast(:door_closed,%{state: :door_open} = data) do
    new_data =
      data
      |> door_closed()
      |> order_complete()
    set_motor(new_data)
    {:noreply,new_data}
  end

  #Helper functions
  def set_motor(%{state: state,dir: dir} = data) do
    case state do
      :idle ->      Driver.set_motor_direction(:stop)
      :door_open -> Driver.set_motor_direction(:stop)
      _ ->          Driver.set_motor_direction(dir)
    end
  end
end

defmodule LiftData do
  defstruct     [:floor,:dir,:state,:hall_up,:hall_down,:cab]
  @enforce_keys [:floor,:dir,:state,:hall_up,:hall_down,:cab]
  @valid_orders [:hall_up,:hall_down,:cab]
  @valid_dir    [:up,:down]
  @states       [:init,:idle,:mooving,:door_open]

  def new_list(floors,floor,dir,state)
    when is_integer(floors) and is_integer(floor)
    and dir in @valid_dir and state in @states do
    %LiftData{
      floor:     floor,
      dir:       dir,
      state:     state,
      hall_up:   List.duplicate(false, floors),
      hall_down: List.duplicate(false, floors),
      cab:       List.duplicate(false, floors)
    }
  end

  def new_list(floors,dir,state)
  when is_integer(floors)
  and dir in @valid_dir and state in @states do
    %LiftData{
      floor:     nil,
      dir:       dir,
      state:     state,
      hall_up:   List.duplicate(false, floors),
      hall_down: List.duplicate(false, floors),
      cab:       List.duplicate(false, floors)
    }
  end

  def update_state(data,new_state) when new_state in @states do
    Map.put(data,:state,new_state)
  end

  def filter_orders(data) do
    Map.filter(data,fn entry -> entry in @valid_orders end)
  end

  def update_order_type(data,floor,button_type,new_order) do
    new_orders = data
    |> Map.fetch!(button_type)
    |> List.replace_at(floor,new_order)
    Map.put(data, button_type, new_orders)
  end

  def insert_new_order(data,floor,button_type)
  when is_integer(floor) and button_type in @valid_orders do
    update_order_type(data,floor,button_type,true)
  end

  def order_complete(%LiftData{floor: floor, dir: :up} = data) do
      data
      |> update_order_type(floor,:cab,false)
      |> update_order_type(floor,:hall_up,false)
  end

  def order_complete(%LiftData{floor: floor, dir: :down} = data) do
      data
      |> update_order_type(floor,:cab,false)
      |> update_order_type(floor,:hall_down,false)
  end


  def order_at_floor?(%LiftData{cab: cab, hall_up: hall,floor: floor, dir: :down}) do
    Enum.fetch!(cab,floor) or Enum.fetch!(hall,floor)
  end

  def order_at_floor?(%LiftData{cab: cab, hall_up: hall,floor: floor, dir: :up}) do
    Enum.fetch!(cab,floor) or Enum.fetch!(hall,floor)
  end

  def order_above?(%LiftData{floor: floor} = data) do
    data
    |> filter_orders
    |> Map.values
    |> Enum.any?(&(order_above?(&1,floor)))
  end

  def order_above?(orders,floor) when is_list(orders) do
    orders
    |> Enum.slice(floor+1,length(orders))
    |> Enum.any?
  end

  def order_below?(%LiftData{floor: floor} = data) do
    data
    |> filter_orders
    |> Map.values
    |> Enum.any?(&order_below?(&1,floor))
  end

  def order_below?(orders,floor) when is_list(orders) do
    orders
    |> Enum.slice(0,floor)
    |> Enum.any?
  end

  def order_ahead?(%LiftData{dir: :up} = data) do
    order_above?(data)
  end

  def order_ahead?(%LiftData{dir: :down} = data) do
    order_below?(data)
  end

  def opposite_dir(:up), do: :down
  def opposite_dir(:down), do: :up

  def change_dir(%LiftData{dir: :down} = data) do
    Map.put(data, :dir, :up)
  end

  def change_dir(%LiftData{dir: :up} = data) do
    Map.put(data, :dir, :down)
  end

  def at_floor(%LiftData{floor: floor, dir: dir} = data) do
    cond do
      order_at_floor?(data) -> :stop
      order_ahead?(data) -> dir
      true -> :stop
    end
  end

  def door_closed(%LiftData{floor: floor, dir: dir,state: state} = data) do
    {next_state,next_dir} =
    cond do
      order_ahead?(data)    -> {:mooving,dir}
      order_at_floor?(data) -> {:door_open,dir}
      order_ahead?(data)    -> {:mooving,opposite_dir(dir)}
      true ->                  {:idle,dir}
    end
    data
    |> Map.put(:dir,next_dir)
    |> Map.put(:state,next_state)
  end
end
