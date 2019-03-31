defmodule ButtonPoller.Supervisor do
    use Supervisor
  
    def start_link([floors]) do
      Supervisor.start_link(__MODULE__, {:ok, floors}, name: Button.Supervisor)
    end
  
    @doc """
    Initializes the supervisor for the button poller. Turns off all button lights.
    @spec init(:ok, floors :: integer) :: {:ok, tuple()}
    """
    def init({:ok, floors}) do
      available_order_buttons = get_all_buttons(floors)
  
      Enum.each(available_order_buttons, fn button ->
        Driver.set_order_button_light(button.floor, button.type, :off)
        end)
  
      children =
        Enum.map(available_order_buttons, fn button ->
          ButtonPoller.child_spec(button.floor, button.type)
        end)
  
      opts = [strategy: :one_for_one, name: Button.Supervisor]
      Supervisor.init(children, opts)
    end
  
    #Credited: Jostein Løwer. https://github.com/jostlowe/kokeplata/tree/master/lib (24.03.19)
    def get_all_button_types do
      [:hall_up, :hall_down, :cab]
    end
  
    #Credited: Jostein Løwer. https://github.com/jostlowe/kokeplata/tree/master/lib (24.03.19)
    def get_buttons_of_type(button_type, top_floor) do
      floor_list =
        case button_type do
          :hall_up -> 0..(top_floor - 1)
          :hall_down -> 1..top_floor
          :cab -> 0..top_floor
        end
      floor_list |> Enum.map(fn floor -> %{floor: floor, type: button_type} end)
    end
  
    #Credited: Jostein Løwer. https://github.com/jostlowe/kokeplata/tree/master/lib (24.03.19)
    def get_all_buttons(floors) do
      top_floor = floors - 1
  
      get_all_button_types()
      |> Enum.map(fn button_type -> get_buttons_of_type(button_type, top_floor) end)
      |> List.flatten()
    end
  end
  
  