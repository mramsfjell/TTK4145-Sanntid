defmodule Auction.Supervisor do
    def start_link(_args) do
      DynamicSupervisor.start_link(name: :auction_supervisor)
    end
  
    def start_child(order) do
      DynamicSupervisor.start_child(__MODULE__, {Auction, order})
    end
end
  