defmodule IO.Button do
  use Task

  def start_link(button_info) do
    Task.start_link(__MODULE__, :button_poll, [button_info])
  end

  def child_spec([id|button_info]) do
    %{id: id,
      start: {__MODULE__,:start_link,[button_info]},
      restart: :permanent,
      type: :worker
    }
  end

  def button_poll button_info = [driver_pid,button,floor] do
    case Driver.get_order_button_state(driver_pid,floor,button) do
      1 -> IO.puts "#{button} at floor #{floor} pushed"
            #Elevator.Orderlist.add(:order_list,floor,button)
            Process.sleep(1000)
      0 -> Process.sleep(100)
    end
    button_poll button_info
  end
end

defmodule IO.FloorSensor do
  use Task
  def start_link(driver,lift) do
    Task.start_link(__MODULE__,:floor_sensor_poll,[driver,lift])
  end

  def floor_sensor_poll(driver_pid,lift) do
    case Driver.get_floor_sensor_state(driver_pid) do
      :between_floors ->
        Process.sleep(100)
        floor_sensor_poll driver_pid,lift
      floor ->
        Driver.set_floor_indicator(driver_pid,floor)
        #Lift.FSM.send
        #turn on light
        #Decide if poll continiously or only when mooving
        Process.sleep(2_000)
        floor_sensor_poll driver_pid,lift
    end
  end
end
