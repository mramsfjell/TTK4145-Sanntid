defmodule Lift.FSM do
  use GenStateMachine

  @name :Lift_FSM

  def start_link(args \\[]) do
    GenStateMachine.start_link(__MODULE__,args,[name: @name])
  end

  def init(args = [floors]) do
    case Driver.get_floor_sensor_state() do
      :between_floors ->
        data = %{floor: nil,
            direction: :up,
            orders: Lift.Orderlist.new(floors)}
        Driver.set_motor_direction(:up)
        {:ok,:init,data}
      floor ->
        data = %{floor: floor,
            direction: :up,
            orders: Lift.Orderlist.new(floors)}
        {:ok,:idle,data}
      end
  end

  def at_floor(floor) do
    GenStateMachine.cast(@name,{:at_floor,floor})
  end


  def get_state() do
    GenStateMachine.call(@name,:get_state)
  end

  def new_order(floor,button_type) do
    GenStateMachine.call(@name,{:new_order,floor,button_type})
  end

  def door_closed() do
    GenStateMachine.cast(@name,:door_closed)
  end

  #Callbacks
  def handle_event(:cast,{:at_floor,floor},:mooving,data) do
    new_state =
    case Lift.Orderlist.at_floor(data.orders,floor,data.direction) do
      :stop ->
        Driver.set_motor_direction(:stop)
        :door_open
      _other ->
        :mooving
    end
    new_data = Map.put(data, :floor, floor)
    {:next_state,new_state,data}
  end

  def handle_event(:cast,{:at_floor,floor},:init,data) do
    #Tell controller I'm alive a %{controller: #PID<0.185.0>, driver: #PID<0.186.0>}}
    Driver.set_motor_direction(:stop)
    new_data = Map.put(data, :floor, floor)
    {:next_state,:idle,new_data}
  end

  def handle_event(:cast,{:at_floor,floor},_state,_data) do
    :keep_state_and_data
  end


  def handle_event(:cast,{:door_closed},:door_open, %{floor: floor, orders: orders, direction: dir} = data) do
    next_state =
    case Lift.Orderlist.door_closed(orders,floor,dir) do
      :stop ->
        :idle
      motor_dir ->
        Driver.set_motor_direction(motor_dir)
        :mooving
    end
    new_orders = Lift.Orderlist.order_done(orders,floor,dir)
    new_data = Map.put(data,:orders,new_orders)
    {:next_state,next_state,data}
  end

  def handle_event({:call,from},{:new_order,floor,button_type},:idle,data) do
    new_orders = Lift.Orderlist.new_order(data.orders,floor,button_type)
    new_data = Map.put(data, :orders, new_orders)
    new_state =
      case Lift.Orderlist.door_closed(new_orders,data.floor,data.direction) do
        :stop -> Driver.set_door_open_light(:on)
          :door_open
        dir -> Driver.set_motor_direction(dir)
          :mooving
      end
    {:next_state,new_state,new_data ,[{:reply, from, :ok}]}
  end

  def handle_event({:call,from},{:new_order,floor,button_type},_state,data) do
    new_orders = Lift.Orderlist.new_order(data.orders,floor,button_type)
    new_data = Map.put(data, :orders, new_orders)
    {:keep_state,new_data,[{:reply, from, :ok}]}
  end


  def handle_event({:call,from},:get_state,state,data) do
    IO.puts state
    {:keep_state_and_data, [{:reply, from, {state,data}}]}
  end
end


defmodule Lift.Orderlist do
  defstruct [:hall_up,:hall_down,:cab]
  @enforce_keys [:hall_up,:hall_down,:cab]
  @valid_order [:hall_up,:hall_down,:cab]
  @valid_dir [:up,:down]


  def new(floors) do
    %Lift.Orderlist {
      hall_up: List.duplicate(false, floors),
      hall_down: List.duplicate(false, floors),
      cab: List.duplicate(false, floors)
    }
  end

  def new_order(orders,floor,button_type)
  when is_integer(floor) do
    new_list = orders
    |> Map.fetch!(button_type)
    |> List.replace_at(floor,true)
    Map.replace!(orders, button_type,new_list)
  end

  def valid?(%Lift.Orderlist{} = orders), do: true
  def valid?(_), do: false


  def order_complete(%Lift.Orderlist{cab: cab,hall_up: hall} = orders,floor,:up)
    when is_integer(floor) do
      new_cab = cab |> List.replace_at(floor,false)
      new_hall = hall |> List.replace_at(floor,false)
      orders
      |> Map.replace!(:cab, new_cab)
      |> Map.replace!(:hall_up, new_hall)
  end

  def order_complete(%Lift.Orderlist{cab: cab, hall_down: hall} = orders,floor,:down)
  when is_integer(floor) do
    new_cab = cab |> List.replace_at(floor,false)
    new_hall = hall |> List.replace_at(floor,false)
    orders
      |> Map.replace!(:cab, new_cab)
      |> Map.replace!(:hall_down, new_hall)
  end


  def order_at_floor?(%Lift.Orderlist{cab: cab, hall_down: hall},floor,:down)
    when is_integer(floor) do
    Enum.fetch!(cab,floor) or Enum.fetch!(hall,floor)
  end

  def order_at_floor?(%Lift.Orderlist{cab: cab, hall_up: hall},floor,:up)
    when is_integer(floor) do
    Enum.fetch!(cab,floor) or Enum.fetch!(hall,floor)
  end

  def order_above?(%Lift.Orderlist{} = orders,floor) do
    orders
    |> Map.values
    |> Enum.drop(1)
    |> Enum.any?(&(order_above?(&1,floor)))
  end

  def order_above?(orders,floor) when is_list(orders) do
    orders
    |> Enum.slice(floor+1,length(orders))
    |> Enum.any?
  end

  def order_below?(%Lift.Orderlist{} = orders ,floor) do
    orders
    |> Map.values
    |> Enum.drop(1)
    |> Enum.any?(&order_below?(&1,floor))
  end

  def order_below?(orders,floor) when is_list(orders) do
    orders
    |> Enum.slice(0,floor)
    |> Enum.any?
  end

  def order_ahead?(%Lift.Orderlist{} = orders,floor,:up) do
    order_above?(orders,floor)
  end

  def order_ahead?(%Lift.Orderlist{} = orders,floor,:down) do
    order_below?(orders,floor)
  end

  def opposite_dir(:up), do: :down
  def opposite_dir(:down), do: :up

  def at_floor(%Lift.Orderlist{} = orders,floor,dir) do
    cond do
      order_at_floor?(orders,floor,dir) -> :stop
      order_ahead?(orders,floor,dir) -> dir
      true -> :stop
    end
  end

  def door_closed(%Lift.Orderlist{} = orders,floor,dir) do
    cond do
      order_ahead?(orders,floor,dir) ->  dir
      order_at_floor?(orders,floor,opposite_dir(dir)) -> :stop
      order_ahead?(orders,floor,opposite_dir(dir)) -> opposite_dir(dir)
      true -> :stop
    end
  end
end
