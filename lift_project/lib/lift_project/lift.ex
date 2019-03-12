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

  def new_order(floor,dir) do
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
            state: :mooving,
            order: nil,
            floor: 0,
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
    new_data =
    case data.state do
      :mooving      -> at_floor(data,floor)
      _other_state  -> data
    end
    {:noreply,%Lift{} = new_data}
  end


  def handle_cast({:new_order, order}, %Lift{state: state} = data) do
    new_data = handle_new_order(data,order)
    {:noreply,%Lift{} = new_data}
  end

  def handle_call(:get_state,_from,data) do
    {:reply,data,data}
  end


  def handle_info(:close_door,data = %Lift{state: :door_open}) do
    new_data = hande_door_close(data)
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

  #Helper functions
  defp hande_door_close(%Lift{} = data) do
    Driver.set_door_open_light(:off)
    data = Map.put(data,:order,nil) #Remoove when OrderServer implemented
    #OrderServer.order_complete(data.order)
    new_data =
      case  request_new_order(data) do
        nil
          ->  idle_transition(data)
        order->
            data
            |> add_order(order)
            |> mooving_transition()
    end
  end


  defp handle_new_order(%Lift{state: :idle} = data, %LiftOrder{} = order) do
    if order_at_floor?(order,data.floor) do
      data
      |> add_order(order)
      |> door_open_transition
    else
       data
      |> add_order(order)
      |> update_direction
      |> at_floor(data.floor)
    end
  end

  defp handle_new_order(%Lift{} = data, %LiftOrder{} = order) do
    data
  end

  defp at_floor(%Lift{order: order,dir: dir} = data,floor)
  when is_integer(floor) do
    IO.puts "at floor#{floor}"
    data = Map.put(data,:floor,floor)
    if order_at_floor?(order,floor,dir) do
      door_open_transition(data)
    else
      new_order = request_new_order(data)
      data
      |> add_order(new_order)
      |> update_direction
      |> at_floor(new_order)
    end
  end

  defp at_floor(%Lift{floor: floor} = data,%LiftOrder{} = new_order) do
    if order_at_floor?(new_order,floor) do
      door_open_transition(data)
    else
      mooving_transition(data)
    end
  end

  defp request_new_order(%Lift{floor: floor, dir: dir} = data) do
    #OrderServer.at_floor(floor,dir)
    data.order
  end

  defp order_at_floor?(%LiftOrder{} = order,floor,dir) do
    order.floor == floor and order.dir == dir
  end

  defp order_at_floor?(nil,_floor,_dir), do: true
  defp order_at_floor?(nil,_floor), do: true

  defp order_at_floor?(%LiftOrder{} = order,floor) do
    order.floor == floor
  end

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
