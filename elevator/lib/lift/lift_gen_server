defmodule Lift do
  use GenServer
  @name :FSM
  def start_link do
    GenServer.start(__MODULE__,%{}.[name: @name])
  end

  def init(state) do
    case Driver.get_floor_sensor_state() do
      :between_floors ->
        state = %{floor: nil, direction: :up}
        Driver.set_motor_direction(:up)
        {:ok,:init,state}
      floor ->
        state = %{floor: floor, direction: :up}
        {:ok,:idle,state}
      end
  end

  def at_floor(floor) do
    GenServer.cast(@name,{:at_floor,floor})
  end


  def get_state() do
    GenServer.cast(@name,{:get_state})
  end

  #Callbacks
  def handle_cast({:at_floor,floor},state) do
    #Ask kontroller for direction
    new_state =
    case dummy_answer = :stop do
      :stop ->
        Driver.set_motor_direction(:stop)
        :door_open
      _other ->
        :mooving
    end
    {:next_state,new_state,state}
  end

  def handle_cast({:at_floor,floor},:state) do
    #Tell controller I'm alive a %{controller: #PID<0.185.0>, driver: #PID<0.186.0>}}
    Driver.set_motor_direction(:stop)
    {:next_state,:idle,state}
  end


  def handle_cast({:start_handling},state) do
    new_state =
      #Ask controller what to do
    case dummy_answer = :stop do
      :stop ->
        Driver.set_door_open_light(:on)
        #Start timer
        :door_open
      motor_dir ->
        Driver.set_motor_direction(motor_dir)
        :mooving
    end
    {:next_state,new_state,state}
  end

  def handle_cast({:start_handling},state) do
    #Ask controller what to do
    :keep_state_and_state
  end


  def handle_event(:cast,{:close_door},:door_open,state) do
    Driver.set_door_open_light(:off)
    #Ask controller what to do
    new_state =
      #Ask controller what to do
    case dummy_answer = :stop do
      :stop ->
        :idle
      motor_dir ->
        Driver.set_motor_direction(motor_dir)
        :mooving
    end
    {:next_state,new_state,state}
  end

  def handle_call({:get_state},_from,state) do
    {:reply,state,state}

  end

  def handle_event(msg,state) do
    IO.puts "hei ugyldig input: #{msg}"
    {:noreply,state}
  end
end
