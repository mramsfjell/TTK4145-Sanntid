defmodule WatchDog do
    @moduledoc """
    This module is meant to take care of any order not being handled within
    reasonable time, set by the timer length @watchdog_timer.

    A process starts each time an order's watch_node is set up. If the timer
    of a specific order goes out before the order_complete message is received,
    this order is reinjected to the system by the order distribution logic.
    If everything works as expected, the process is killed when the order_complete
    message is received.



    Use genserver whith list of all assigned orders. Use process.send_after to
    take care of expiered timers. Also handle Node down/up
    """
    @name :watch_dog
    @watchdog_timer 60_000

    use GenServer
    @cab_orders [:cab]
    @hall_orders [:hall_up, :hall_down]

    def start_link(_args) do
        GenServer.start_link(__MODULE__,[],name: @name)
    end


    #API------------------------------------------------------
    def new_order(order) do
      GenServer.call(@name,{:new_order,order})
    end

    def order_complete(order) do
      GenServer.cast(@name,{:order_complete,order})
    end

    #Callbacks-----------------------------------------------------
    def init([]) do
      :net_kernel.monitor_nodes(true)
      state = %{active: %{}, stand_by: %{}}
      {:ok,state}
    end

    def handle_call({:new_order,order},_from,state) do
      new_state = put_in(state,[:active,order.time],order)
      {:reply,:ok,new_state}
    end

    def handle_cast({:order_complete,order},state) do
      {_complete, updated_state} = pop_in(state, [:active,order.time])
      {:noreply,updated_state}
    end

    def handle_info({:nodedown,node_name},state) do
      with
      dead_node_orders <- fetch_node(state,node_name),
      cab_orders   <- fetch_order_type(dead_node_orders,:cab),
      hall_orders  <- fetch_order_type(dead_node_orders,:hall)
      do
        reinject_order(hall_orders)
        updated_orders = moove_to_standby(state,cab_orders)
        {:noreply,updated_orders}
      end
    end

    def fetch_node(state,node_name) do
      state
        |> Map.get(:active)
        |> Map.values
        |> Enum.filter(fn order -> order.node == node_name end)
    end

    def fetch_order_type(orders,:cab) do
      Enum.filter(orders,fn order -> order.button_type in @cab_orders end)
    end

    def fetch_order_type(orders,:hall) do
      Enum.filter(orders,fn order -> order.button_type in @hall_orders end)
    end

    def reinject_order(orders)
      when is_list(orders)
      do
        Enum.each(orders,fn order -> reinject_order(order) end)
    end

    def reinject_order(%Order{} = order) do
      OrderDistribution.new_order(order)
    end

    def moove_to_standby(state,orders) do
      state
    end
end
