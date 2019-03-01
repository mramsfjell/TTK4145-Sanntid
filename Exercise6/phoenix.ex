defmodule Phoenix do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok,[name: :phoenix])
  end

  def init(:ok) do
    children = [
      {Phoenix.Backup,[]},
      {Phoenix.Primary,[]}
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end

end

defmodule Phoenix.Primary do
  use GenServer
  def start_link(_args) do
    GenServer.start_link(__MODULE__,%{},name: :primary)
  end

  def kill do
    Process.exit(Process.whereis(:primary), :kill)
  end

  def init(state) do
    start_value = Phoenix.Backup.get_value
    state = Map.put(state,:value,start_value)
    IO.puts("start #{state.value}")
    Process.send_after(self, :count, 1_000)
    {:ok,state}
  end

  def handle_info(:count,state) do
    new_state = Map.update!(state,:value,&(&1+1))
    Phoenix.Backup.set_value new_state.value
    IO.puts new_state.value
    Process.send_after(self, :count, 1_000)
    {:noreply,new_state}
  end
end

defmodule Phoenix.Backup do
  use GenServer
  def start_link(primary) do
    GenServer.start_link(__MODULE__,%{},[name: :backup])
  end

  def set_value(value) do
    GenServer.cast(:backup,{:set,value})
  end

  def get_value do
    GenServer.call(:backup,{:get})
  end

  def init(state) do
    new_state =  state |> Map.put(:value,0)
    {:ok,new_state}
  end

  def handle_cast({:set,value},state) do
    new_state = Map.put(state,:value,value)
    {:noreply,new_state}
  end

  def handle_call({:get},_from,state) do
    IO.puts("Backup #{state.value}")
    {:reply,state.value,state}
  end

  def handle_info(msg,state) do
    msg |> inspect |> IO.puts
    {:noreply,state}
  end
end
