defmodule WatchDog do
  use
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
    Finn get_my_ip på kokeplata
    """
    use Task
    @name :watch_dog
    @watchdog_timer 60_000

    def start_link(_args) do
        Task.start_link(__MODULE__,[],name: @name)
    end

    receive do


    after @watchdog_timer

    # Callbacks

    def handle_info() do
        Process.send_after(self(),{:timer_finished,order},@watchdog_timer)
    end

    def handle_info(:order_complete) do
        Process.exit(self(),:kill)
    end

    def handle_info({:timer_finished,order}) do
        {_reply,reason,_state} = OrderDistribution.new_order(order)
        case reason do
            :ok -> Process.exit(self(),:kill)
            _ -> Process.send(self(),{:timer_finished,order},[:noconnect])
        end
    end
end
