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

  def button_poll button_info = [button,floor] do
    case Driver.get_order_button_state(floor,button) do
      1 -> IO.puts "#{button} at floor #{floor} pushed"
            #Elevator.Orderlist.add(:order_list,floor,button)
            Process.sleep(2000)
      0 -> Process.sleep(500)
    end
    button_poll(button_info)
  end
end

defmodule FloorSensor do
  use Task
  def start_link(_arg \\ []) do
    Task.start_link(__MODULE__,:floor_sensor_poll,[])
  end

  def floor_sensor_poll() do
    case Driver.get_floor_sensor_state() do
      :between_floors ->
        Process.sleep(200)
        floor_sensor_poll()
      floor ->
        Driver.set_floor_indicator(floor)
        Lift.at_floor(floor)
        Process.sleep(1000)
        floor_sensor_poll()
    end
  end
end
