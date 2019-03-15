defmodule LiftOrder do
  defstruct [:floor,:dir]
  @valid_dir [:up,:down]
  @enforce_keys [:floor,:dir]

  def new({floor,dir})
    when is_integer(floor) and dir in @valid_dir
    do
      %LiftOrder{
        floor: floor,
        dir: dir
      }
  end

  def new(floor,dir) do
    new({floor,dir})
  end
end

defmodule Lift do
  @moduledoc """
   Provides a function `hello/1` to greet a human
   """
  use GenServer

  defstruct [:floor,:dir,:order,:state]
  @enforce_keys [:floor,:dir,:order,:state]
  @name :Lift_FSM
  @door_timer 5_000

  def start_link(args \\[]) do
    GenServer.start_link(__MODULE__,args,[name: @name])
  end

  def at_floor(floor) do
    GenServer.cast(@name,{:at_floor,floor})
  end

  def new_order({floor,dir}) do
    order = LiftOrder.new(floor,dir)
    GenServer.cast(@name, {:new_order,order})
  end

  def get_state() do
    GenServer.call(@name,:get_state)
  end



  #Callbacks
  def init([]) do
    data =
      case Driver.get_floor_sensor_state() do
        :between_floors ->
          Driver.set_motor_direction(:up)
          %Lift{
            state: :init,
            order: nil,
            floor: nil,
            dir: :up
            }

        floor ->
          %Lift{
            state: :idle,
            order: nil,
            floor: floor,
            dir: :up
            }
        end
      {:ok,data}
  end

  def handle_cast({:set,new_data},data) do
    {:noreply,new_data}
  end

  def handle_cast({:at_floor,floor}, data) do
    OrderServer.at_floor(floor,data.dir)
    new_data =
    case data.state do
      :mooving      -> at_floor_event(data,floor)
      :init         -> complete_init(data,floor)
      _other_state  -> data #this can be remooved when io is working
    end
    {:noreply,%Lift{} = new_data}
  end


  def handle_cast({:new_order, order}, data) do
    new_data = new_order_event(data,order)
    {:noreply,%Lift{} = new_data}
  end

  def handle_call(:get_state,_from,data) do
    {:reply,data,data}
  end


  def handle_info(:close_door,data = %Lift{state: :door_open}) do
    new_data = door_close_event(data)
    {:noreply,%Lift{} = new_data}
  end


  #State transitions
  defp door_open_transition(%Lift{} = data) do
    Driver.set_motor_direction(:stop)
    Driver.set_door_open_light(:on)
    Process.send_after(self(), :close_door,@door_timer)
    IO.puts "Door open at floor #{data.floor}"
    Map.put(data,:state,:door_open)
  end

  defp mooving_transition(%Lift{dir: dir} = data) do
    Driver.set_door_open_light(:off)
    new_state = Map.put(data, :state, :mooving)
    IO.puts("Mooving #{dir}")
    Driver.set_motor_direction(dir)
    new_state

  end

  defp idle_transition(%Lift{} = data) do
    Driver.set_motor_direction(:stop)
    Driver.set_door_open_light(:off)
    IO.puts("Ideling at floor #{data.floor}")
    Map.put(data, :state, :idle)
  end

  defp complete_init(data,floor) do
    Driver.set_motor_direction(:stop)
    OrderServer.at_floor(floor,data.dir)
    OrderServer.lift_ready()
    data
      |>Map.put(:floor, :floor)
      |>Map.put(:state, :idle)
  end

  #Events
  defp door_close_event(%Lift{order: order} = data) do
    Driver.set_door_open_light(:off)
    OrderServer.order_complete(data.order.floor,data.order.dir)
    data = Map.put(data,:order,nil)
    idle_transition(data)
  end


  defp new_order_event(%Lift{state: :idle} = data, %LiftOrder{} = order) do
    if order_at_floor?(order,data.floor) do
      data
      |> add_order(order)
      |> door_open_transition
    else
       data
      |> add_order(order)
      |> update_direction()
      |> at_floor_event()
    end
  end

  defp new_order_event(%Lift{} = data, %LiftOrder{} = order) do
    add_order(data,order)
  end

  defp at_floor_event(%Lift{floor: floor, order: order} = data) do
    IO.puts "at floor#{floor}"
    if order_at_floor?(order,floor) do
      door_open_transition(data)
    else
      mooving_transition(data)
    end
  end

  defp at_floor_event(data,floor) do
    data
    |> Map.put(:floor,floor)
    |> at_floor_event()
  end

  #Helper functions
  defp order_at_floor?(%LiftOrder{} = order,floor,dir) do
    order.floor == floor and order.dir == dir
  end

  defp order_at_floor?(%LiftOrder{} = order,floor) do
    order.floor == floor
  end

  defp order_at_floor?(nil,_floor,_dir), do: true
  defp order_at_floor?(nil,_floor), do: true

  defp add_order(%Lift{} = data,order) do
    Map.put(data,:order, order)
  end

  defp update_direction(%Lift{} = data) do
    if data.floor < data.order.floor do
      Map.put(data,:dir,:up)
    else
      Map.put(data, :dir, :down)
    end
  end
end
