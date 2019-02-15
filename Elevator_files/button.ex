defmodule Button do
  use Task
  def start_link(args) do
    Task.start_link(__MODULE__, :button_poll, [args])
  end

  def button_poll args = {pid,button,floor} do
    case Driver.get_order_button_state(pid,floor,button) do
      1 -> IO.puts "#{button} at floor #{floor} pushed"
            Elevator.Orderlist.add(:order_list,floor,button)
            Process.sleep(1000)
      0 -> Process.sleep(100)
    end
    button_poll args
  end
end

defmodule FloorSensor do
  use Task
  def start_link(driver) do
    Task.start_link(__MODULE__,:floor_sensor_poll,[driver])
  end

  def floor_sensor_poll(driver_pid) do
    case Driver.get_floor_sensor_state(driver_pid) do
      :between_floors ->
        Process.sleep(10)
        floor_sensor_poll driver_pid
      floor ->
        IO.puts floor
        {:ok,floor}
    end
  end
end
