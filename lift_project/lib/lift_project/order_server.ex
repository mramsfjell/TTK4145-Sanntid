defmodule Order do

  defstruct [:floor,:button_type,:time,node: nil,watch_node: nil]
  @valid_order [:hall_down, :cab, :hall_up]
  @enforce_keys [:floor,:button_type]

  def new(floor,button_type)
    when is_integer(floor) and  button_type in @valid_order
    do
      %Order{
        floor: floor,
        button_type: button_type,
        time: Time.utc_now()|> Time.truncate(:second),
        node: Node.self
      }
  end
end

defmodule OrderServer do
  @valid_dir [:up,:down]
  @name :order_server
  use GenServer

  #%{active: %{node%{time%{order}}}, complete: %{node%{time%{order}}}, :floors}

  def start_link(_args)do
    GenServer.start_link(__MODULE__,[],[name: @name])
  end

  def at_floor(floor,dir) do
    GenServer.cast(@name,{:at_floor,floor,dir})
  end

  def order_complete(floor,dir)
  when is_integer(floor) and dir in @valid_dir
  do
    GenServer.cast(@name,{:order_complete,floor,dir})
  end

  def order_complete(%Order{} = order) do
    GenServer.cast(@name,{:order_complete,order})
  end

  def evaluate_cost(order) do
    GenServer.call(@name,{:evaluate_cost,order})
  end

  def new_order(order) do
    GenServer.call(@name,{:new_order,order})
  end

  def get_orders() do
    GenServer.call(@name,{:get})
  end

  #Callbacks
  def init(_args) do
    state = %{
      active: %{Node.self => %{}},
      complete: %{Node.self => %{}},
      floor: nil,
      dir: nil,
      last_order: nil
    }
    {:ok,state}
  end

  def handle_cast({:at_floor,floor,dir},state) do
    new_state =
      state
      |> Map.put(:floor,floor)
      |> Map.put(:dir,dir)
    {:noreply,new_state}
  end

  def handle_cast({:order_complete,floor,dir},state) do
    orders = fetch_orders(state.active, Node.self,floor,dir)
    broadcast_complete_order(orders)
    new_state =
      state
      |> Map.put(last_order: nil)
      |> remove_orders(orders)
      |> assign_new_lift_order
    #Notify watch dog
    {:noreply,new_state}
  end

  def handle_call({:evaluate_cost,order},_from,state) do
    cost = calculate_cost(order,state)
    {:reply,cost,state}
  end


  def handle_call({:new_order,order},_from,state) do
    new_state =
      state
      |> add_order(order)
      #|> assign_new_lift_order
      #|> assign_watch_dog
    {:reply,order,new_state}
  end

  def handle_call({:get},_from, state) do
    IO.inspect(state)
    {:reply,{:ok,state},state}
  end

  def handle_info({:order_complete,order},state) do
    IO.inspect(order)
    new_state =
      state
      |> remove_order(order)
      #Notify watch_dog
    {:noreply,state}
  end




  #Helper functions
  def add_order(state, order) do
    add_order_to_list(state,:active,order)
  end

  def remove_orders(state, orders) do
    Enum.reduce(orders, state, fn(order,int_state) -> remove_order(int_state,order) end)
  end

  def remove_order(state, %Order{node: node, time: time} = order) do
    {_complete_order,new_state} = pop_in(state, [:active,node,time])
    add_order_to_list(new_state,:complete,order)
  end


  def add_order_to_list(state, order_state, %Order{} = order)
  when is_atom(order_state) do
    list = Map.fetch!(state,order_state)
    if  Map.has_key?(list, order.node) do
      put_in(state, [order_state,order.node,order.time],order)
    else
      #Create node in data structure, then insert order
      put_in(state, [order_state,order.node], %{order.time => order})
    end
  end

  def order_at_floor?(order,floor,:up) do
    order.floor == floor and (order.button_type == :cab or order.button_type == :hall_up)
  end

  def order_at_floor?(%Order{floor: o_floor, button_type: button},floor,:down) do
    o_floor == floor and (button == :cab or button== :hall_down)
  end

  def fetch_orders(orders,node,floor,dir) do
    orders
    |> Map.fetch!(node)
    |> Map.values
    |> Enum.filter(&order_at_floor?(&1,floor,dir))
  end

  def send_comlete_order(remote_node,order) do
  #Do something to check that the message were sent?
    Process.send({:order_server,remote_node},{:order_complete,order},[:noconnect])
  end

  def broadcast_complete_order(orders)
  when is_list(orders) do
    Enum.each(orders, fn order -> broadcast_complete_order(order) end)
  end


  def broadcast_complete_order(order) do
    Node.list
    |> Enum.each(fn(remote_node) ->
        send_comlete_order(remote_node,order)
    end)
  end

  def next_order(%{floor: floor, dir: :up} = state) do
    #Need to be smarter now only chooses closest order.
    state
    |> Map.fetch!(:active)
    |> Map.fetch!(Node.self)
    |> Map.values
    |> Enum.min_by(fn order -> abs(order.floor - floor) end)
  end

  def order_to_dir(order,state) do
    dir =
    case order.button_type do
      :hall_up -> :up
      :hall_down -> :down
      :cab -> state.dir
    end
    {state.floor,dir}
  end

  def assign_new_lift_order(state) do
    next_order = next_order(state) |> order_to_dir
    if next_order != state.last_order do
      Lift.new_order(next_order)
      Map.put(state,:last_order,next_order)
    end
  end

  def count_orders(state) do
    state
    |> Map.fetch!(:active)
    |> Map.fetch!(Node.self)
    |> Map.values
    |> Enum.count()
  end


  def calculate_cost(order,state) do
    count_orders(state)
  end
end
