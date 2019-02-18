defmodule Lift.FSM do
  use GenStateMachine

  def start_link(controller_pid,driver_pid) do
    GenStateMachine.start_link(__MODULE__,%{controller: controller_pid, driver: driver_pid},[name: :FSM])
  end

  def init(data) do

    Task.start_link(IO.FloorSensor,:floor_sensor_poll,[data.driver,self()])
    case Driver.get_floor_sensor_state(data.driver) do
      :between_floors ->
        Driver.set_motor_direction(data.driver,:up)
        {:ok,:init,data}
      floor ->
        {:ok,:idle,data}
      end
  end


  def at_floor(lift_pid, floor) do
    GenStateMachine.cast(lift_pid,{:at_floor,floor})
  end

  def button_pushed(lift_pid,floor,button_type) do
    GenStateMachine.cast(lift_pid,{:button_push,floor,button_type})
  end

  def set_button_light(lift_pid, floor,button_type, state) do
    GenStateMachine.cast(lift_pid,{:set_light,floor,button_type, state})
  end

  def start_handling(lift_pid) do
    GenStateMachine.cast(lift_pid,{:start_handling})
  end

  def close_door(lift_pid) do
    GenStateMachine.cast(lift_pid,{:close_door})
  end

  def get_state(lift_pid) do
    GenStateMachine.cast(lift_pid,{:get_state})
  end

  #Callbacks
  def handle_event(:cast,{:at_floor,floor},:mooving,data) do
    #Ask kontroller for direction
    new_state =
    case dummy_answer = :stop do
      :stop ->
        Driver.set_motor_direction(data.driver,:stop)
        :door_open
      _other ->
        :mooving
    end
    {:next_state,new_state,data}
  end

  def handle_event(:cast,{:at_floor,floor},:init,data) do
    #Tell controller I'm alive a %{controller: #PID<0.185.0>, driver: #PID<0.186.0>}}

    Driver.set_motor_direction(data.driver,:stop)
    {:next_state,:idle,data}
  end

  def handle_event(:cast,{:button_push,floor,button_type},:init,data) do
    {:keep_state_and_data}
  end

  def handle_event(:cast,{:button_push,floor,button_type},_state,data) do
    #send to controller
    {:keep_state_and_data}
  end

  def handle_event(:cast,{:set_light,floor,button_type, light_state},:init,data) do
    {:keep_state_and_data}
  end

  def handle_event(:cast,{:set_light,floor,button_type, light_state},_state,data) do
    Driver.set_order_button_light(data.driver,floor,button_type, light_state)
    {:keep_state_and_data}
  end

  def handle_event(:cast,{:start_handling},_state,data) do
    #Ask controller what to do
    {:keep_state_and_data}
  end

  def handle_event(:cast,{:start_handling},:idle,data) do
    new_state =
      #Ask controller what to do
    case dummy_answer = :stop do
      :stop ->
        Driver.set_door_open_light(data.driver,:on)
        #Start timer
        :door_open
      motor_dir ->
        Driver.set_motor_direction(data.driver,motor_dir)
        :mooving
    end
    {:next_state,new_state,data}
  end

  def handle_event(:cast,{:close_door},:door_open,data) do
    Driver.set_door_open_light(data.driver,:off)
    #Ask controller what to do
    new_state =
      #Ask controller what to do
    case dummy_answer = :stop do
      :stop ->
        :idle
      motor_dir ->
        Driver.set_motor_direction(data.driver,motor_dir)
        :mooving
    end
    {:next_state,new_state,data}
  end

  def handle_event(:cast,{:get_state},state,_data) do
    IO.puts state
    {:keep_state_and_data}
  end




end
