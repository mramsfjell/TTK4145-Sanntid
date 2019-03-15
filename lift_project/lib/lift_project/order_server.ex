defmodule Order do

  defstruct [:floor,:button_type,:time,node: nil,watch_dog: nil]
  @valid_order [:hall_down, :cab, :hall_up]
  @enforce_keys [:floor,:button_type]

  def new(floor,button_type)
    when is_integer(floor) and  button_type in @valid_order
    do
      %Order{
        floor: floor,
        button_type: button_type,
        time: Time.utc_now(),
        node: Node.self
      }
  end
end

defmodule OrderServer do
  @valid_dir [:up,:down]
  @up_dir [:cab,:hall_up]
  @down_dir [:cab,:hall_down]
  @name :order_server
  use GenServer

  #%{active: %{node%{time%{order}}}, complete: %{node%{time%{order}}}, :floors}

  def start_link([floors])do
    GenServer.start_link(__MODULE__,[floors],[name: @name])
  end

  def at_floor(floor,dir) do
    GenServer.cast(@name,{:at_floor,floor,dir})
  end

  def order_complete(floor,dir)
  when is_integer(floor) and dir in @valid_dir
  do
    GenServer.cast(@name,{:order_complete,floor,dir})
  end

  def lift_ready() do
    GenServer.cast(@name,{:lift_ready})
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
  def init([floors]) do
    {floor,dir} =
      case Process.whereis(:Lift_FSM) do
        nil -> {nil,nil}
        pid -> Lift.get_state()
      end
    state = %{
      active: %{Node.self => %{}},
      complete: %{Node.self => %{}},
      floor: floor,
      dir: dir,
      last_order: nil,
      floors: floors
    }

    {:ok,%{} = state}
  end

  def handle_cast({:at_floor,floor,dir},state) do
    new_state =
      state
      |> Map.put(:floor,floor)
      |> Map.put(:dir,dir)
    {:noreply,%{} =new_state}
  end

  def handle_cast({:order_complete,floor,dir},state) do
    orders = fetch_orders(state.active, Node.self,floor,dir)
    IO.inspect(orders)
    broadcast_complete_order(orders)
    new_state =
      state
      |> Map.put(:last_order, nil)
      |> remove_order(orders)
      |> assign_new_lift_order
    #Notify watch dog
    {:noreply,%{} =new_state}
  end

  def handle_cast({:lift_ready},state) do
    new_state = assign_new_lift_order(state)
    {:noreply,%{} =new_state}
end

  def handle_call({:evaluate_cost,order},_from,state) do
    cost = calculate_cost(order,state)
    {:reply,cost,%{} =state}
  end


  def handle_call({:new_order,order},_from,state) do
    new_state =
      state
      |> add_order(order)
      |> assign_new_lift_order
      #Only set cab-light in own cab
      Driver.set_order_button_light(order.floor,order.button_type,:on)
    {:reply,order,%{} =new_state}
  end

  def handle_call({:get},_from, state) do
    {:reply,{:ok,state},%{} =state}
  end

  def handle_info({:order_complete,order},state) do
    IO.inspect(order)
    new_state =
      state
      |> remove_order(order)
      #Notify watch_dog
    {:noreply,%{} = new_state}
  end




  #Helper functions
  def add_order(state, order) do
    add_order_to_list(state,:active,order)
  end

  def remove_order(state, orders)
  when is_list(orders)
  do
    Enum.reduce(orders, state, fn(order,int_state) -> remove_order(int_state,order) end)
  end

  def remove_order(state, %Order{node: node_name, time: time} = order) do
    {_complete_order,new_state} = pop_in(state, [:active,node_name,time])
    Driver.set_order_button_light(order.floor,order.button_type,:off)
    new_state
    #add_order_to_list(new_state,:complete,order)
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
    order.floor == floor and order.button_type in @up_dir
  end

  def order_at_floor?(%Order{} = order,floor,:down) do
    order.floor == floor and order.button_type in @down_dir
  end

  def fetch_orders(orders,node_name,floor,dir) do
    orders
    |> Map.fetch!(node_name)
    |> Map.values
    |> Enum.filter(fn order -> order_at_floor?(order,floor,dir) end)
  end

  def send_complete_order(remote_node,order) do
  #Do something to check that the message were sent?
    Process.send({:order_server,remote_node},{:order_complete,order},[:noconnect])
  end

  def broadcast_complete_order(orders)
  when is_list(orders) do
    Enum.each(orders, fn order -> broadcast_complete_order(order) end)
  end


  def broadcast_complete_order(%Order{} = order) do
    Enum.each(Node.list,fn remote_node ->
      send_complete_order(remote_node,order)
      end)
  end


  def fetch_next_order(%{floor: floor, floors: top_floor, dir: dir} = state)
  when is_integer(floor) and is_atom(:dir) do
    state
    |> Map.fetch!(:active)
    |> Map.fetch!(Node.self)
    |> Map.values
    |> fetch_next_order(floor,dir,top_floor)
  end

  def fetch_next_order(orders,floor,dir, top_floor)
    when is_list(orders) and length(orders) == 0 and is_integer(floor) do
      nil
  end

  def fetch_next_order(orders,floor,:up, top_floor)
    when is_list(orders) and length(orders) != 0 and is_integer(floor) do
    next_order = orders
    |> Enum.filter(fn order -> order.button_type in @up_dir end)
    |> Enum.filter(fn order -> order.floor >= floor end)
    |> Enum.min_by(fn order -> order.floor end,fn -> nil end)
    |>IO.inspect
    IO.puts("up")
    case next_order do
      %Order{} -> next_order
      nil      -> fetch_next_order(orders,top_floor,:down,top_floor)
    end
  end

  def fetch_next_order(orders,floor,:down, top_floor)
    when is_list(orders) and length(orders) != 0 and is_integer(floor) do
    next_order = orders
    |> Enum.filter(fn order -> order.button_type in @down_dir end)
    |> Enum.filter(fn order -> order.floor <= floor end)
    |> Enum.max_by(fn order -> order.floor end, fn -> nil end)
    |>IO.inspect
    IO.puts("down")
    case next_order do
      %Order{} -> next_order
      nil      -> fetch_next_order(orders,0,:up,top_floor)
    end
  end

  def order_to_dir(%{} = state,%Order{} = order) do
      dir =
      case order.button_type do
        :hall_up -> :up
        :hall_down -> :down
        :cab -> state.dir
      end
    {order.floor,dir}
  end

  def assign_new_lift_order(state) do
    case fetch_next_order(state) do
      nil   ->
        Map.put(state,:last_order,nil)
      order ->
        next_order = order_to_dir(state,order)
        if next_order != state.last_order do
          Lift.new_order(next_order)
          Map.put(state,:last_order,next_order)
        else
          Map.put(state,:last_order,nil)
        end

      end
  end

  def count_orders(state) do
    state
    |> Map.fetch!(:active)
    |> Map.fetch!(Node.self)
    |> Map.values #Can be dropped?
    |> Enum.count()
  end


  def calculate_cost(order,state) do
    5*count_orders(state)+abs(order.floor-state.floor)
  end
end
