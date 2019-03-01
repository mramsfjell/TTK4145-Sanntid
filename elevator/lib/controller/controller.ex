defmodule Elevator.Controller do
  use GenServer

  def start_link(controller_pid,driver_pid) do
    GenServer.start_link(__MODULE__,%{controller: controller_pid, driver: driver_pid},[name: :Controller])
  end

  #Controller formerly known as FSM

  def init(data) do
    Task.start_link("communicationModule",:communication_poll,"options [data.driver,self()]")
    case OrderList.get_orders(lift) 
      :got_orders ->
        CostFunction.get_direction(data.driver,:#XX)
        {:ok,:operating,data}
      :no_orders -> 
        {:ok,:no_connect,data}
      end
  end



  def start_timer(lift_pid, to_pid) do #start_handling(lift_pid)
    timer_ref = Process.send_after(to_pid, ":hi", 1000)
    GenServer.cast(lift_pid,{:start_timer}, timer_ref)
  end

  def stop_timer(lift_pid) do 
    GenServer.cast(lift_pid,{:stop_timer})
  end

  def request_cost(lift_pid, order_id, orderlist, lastpastfloot, latestorder) do
    GenServer.cast(lift_pid,{:request_cost, order_id}) 
  end

  def get_direction(lift_pid, orderlist)
    GenServer.cast(lift_pid,{:get_direction, orderlist})
  end

  def assign_order(lift_pid, order_id)
    GenServer.cast(lift_pid, {:assign_order, order_id})
  end

  def assign_watchdog(lift_pid, order_id)
    GenServer.cast(lift_pid, {:assign_watchdog, order_id})
  end

  def confirm_order(order_id, orderlist)
    GenServer.cast(order_id, {:confirm_order, order_id})



  #Callbacks
  def handle_event(:cast,{:no_connect}) do
    #CommunicationModule.listen (while loop)
    case dummy_answer = :stop do
      :solo ->
        #listen
        :listen
      _other ->
        :sync_conn
    end
    {:next_state,new_state,data} #?
  end

  def handle_event(:cast,{:request_cost,order_id}) do
    #Tell controller I'm alive a %{controller: #PID<0.185.0>, driver: #PID<0.186.0>}}

    cost = CostFunction.request_cost() #ask cost function up/down #Driver.set_motor_direction(data.driver,:stop)
    {:next_state,:idle,data}
  end


  def handle_cast(:close_door, state) do
        IO.puts "closing doors"
        ElevatorInterface.set_door_open_light(:ElevatorInterface, :off)
        case recursive_remove_orders(state) do
          :nil ->
            IO.puts "no more orders. going idle"
            {:noreply, %{state | direction: :idle}}
          headed_to ->
            IO.write "handling new order: "
            IO.inspect headed_to
            direction = move_towards_order(state, headed_to)
            {:noreply, %{state | direction: direction}}
        end
    end


  def handle_event(:cast,{:stop_timer},timer_ref) do
    cancel_timer(timer_ref)
    {:new_state}
  end

  def handle_event(:cast,{:button_push,floor,button_type},_state,data) do
    #send to controller
    {:keep_state_and_data}
  end

  def handle_event(:cast,{:start_handling},_state,data) do
    #Ask controller what to do
    {:keep_state_and_data}
  end


  def door_timer do
    :timer.sleep(3000)
    doors_closing(:idle) #lift fsm to idle
  end
end