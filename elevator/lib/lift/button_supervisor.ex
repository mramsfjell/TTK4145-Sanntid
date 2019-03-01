defmodule Button.Supervisor do
  use Supervisor

  def start_link (floors) do
    Supervisor.start_link(__MODULE__,{:ok,floors},[name: Button.Supervisor])
  end

  def init({:ok,[floors]}) do
    children = Enum.flat_map(0..(floors-1), fn floor ->
      child =

      cond do
        floor == 0 ->
            [IO.Button.child_spec(["u"<>to_string(floor),:hall_up,floor]),
             IO.Button.child_spec(["c"<>to_string(floor),:cab,floor])]
        floor == (floors-1) ->
            [IO.Button.child_spec(["d"<>to_string(floor),:hall_down,floor]),
             IO.Button.child_spec(["c"<>to_string(floor),:cab,floor])]
        (0 < floor) and (floor < (floors-1)) ->
            [IO.Button.child_spec(["u"<>to_string(floor),:hall_up,floor]),
             IO.Button.child_spec(["d"<>to_string(floor),:hall_down,floor]),
             IO.Button.child_spec(["c"<>to_string(floor),:cab,floor])]
      end
    end)

    opts = [strategy: :one_for_one, name: Button.Supervisor]
    Supervisor.init(children, opts)
  end
end
